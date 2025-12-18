#!/bin/bash
#
# prepnode.sh
#
# This script prepares GB200 NVL compute nodes for L11 diagnostics by:
# - Stopping interfering services (SLURM, Docker, NVIDIA services)
# - Unloading kernel modules
# - Breaking channel bonds (moving IP from bond to physical interface)
#
# Run with sudo on each compute node before diagnostics
#

set -u  # Exit on undefined variables

BOND=bond0
IPINT=enP6p3s0f0np0


# NVIDIA modules (order matters - unload in reverse dependency order)
NVIDIA_MODULES=(
    "nvidia_uvm"        # CUDA Unified Memory
    "gdrdrv"            # GPUDirect RDMA
    "nv_peer_mem"       # Peer memory
    "nv_peermem"        # Peer memory (alternate)
    "nvidia_peermem"    # Peer memory (alternate)
    "nvidia_fs"         # Filesystem
    "nvidia_modeset"    # Mode setting
    "nvidia_drm"        # DRM
    "nvidia"            # Main driver
)

# List of services to stop
SERVICES=(
    "cmd"
    "docker"
    "docker.socket"
    "nvidia-persistenced"
    "nvidia-fabricmanager"
    "nvidia-dcgm-exporter"
    "nvidia-dcgm"
    "nvidia-imex"
    "dcgm"
    "nvsm-api-gateway"
    "nvsm-mqtt"
    "nvsm-notifier"
    "promtail"
    "slurmd"
)

# DRM modules (display/graphics)
DRM_MODULES=(
    "ast"
    "drm_vram_helper"
    "drm_ttm_helper"
    "ttm"
    "nvidia_drm"
    "drm_kms_helper"
    "drm"
)


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#############################################
# Helper Functions                          #
#############################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if a systemd service exists
service_exists() {
    systemctl list-unit-files "$1.service" &>/dev/null
}

# Check if a systemd service is active
service_active() {
    systemctl is-active --quiet "$1"
}

# Stop a service if it exists and is running
stop_service() {
    local service="$1"
    
    if service_exists "$service"; then
        if service_active "$service"; then
            log_info "Stopping service: $service"
            if sudo systemctl stop "$service" 2>/dev/null; then
                log_success "Stopped $service"
            else
                log_warn "Failed to stop $service (may not be critical)"
            fi
        else
            log_info "Service $service already stopped"
        fi
    else
        log_info "Service $service does not exist (skipped)"
    fi
}

# Disable a service if it exists
disable_service() {
    local service="$1"
    
    if service_exists "$service"; then
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_info "Disabling service: $service"
            if sudo systemctl disable "$service" 2>/dev/null; then
                log_success "Disabled $service"
            else
                log_warn "Failed to disable $service (may not be critical)"
            fi
        else
            log_info "Service $service already disabled"
        fi
    fi
}

# Check if a kernel module is loaded
module_loaded() {
    lsmod | grep -q "^$1 "
}

# Unload a kernel module if loaded
unload_module() {
    local module="$1"
    
    if module_loaded "$module"; then
        log_info "Unloading module: $module"
        if sudo rmmod "$module" 2>/dev/null; then
            log_success "Unloaded $module"
        else
            log_warn "Failed to unload $module (may be in use)"
        fi
    else
        log_info "Module $module not loaded (skipped)"
    fi
}

# Force unload module with dependencies
force_unload_module() {
    local module="$1"
    
    if module_loaded "$module"; then
        log_info "Force unloading module: $module (with dependencies)"
        if sudo modprobe --remove --remove-dependencies -f "$module" 2>/dev/null; then
            log_success "Force unloaded $module"
        else
            log_warn "Failed to force unload $module"
        fi
    else
        log_info "Module $module not loaded (skipped)"
    fi
}

#############################################
# Step 1: Kill SLURM processes              #
#############################################

echo ""
log_info "=== Step 1: Stopping SLURM processes ==="

# Kill any running slurmd processes
if pgrep -x slurmd >/dev/null; then
    log_info "Killing slurmd processes"
    sudo pkill -9 slurmd 2>/dev/null || true
    sleep 1
    if pgrep -x slurmd >/dev/null; then
        log_warn "Some slurmd processes still running"
    else
        log_success "All slurmd processes killed"
    fi
else
    log_info "No slurmd processes found"
fi

#############################################
# Step 2: Stop Services                     #
#############################################

echo ""
log_info "=== Step 2: Stopping services ==="


for service in "${SERVICES[@]}"; do
    stop_service "$service"
done

# Disable nvidia-persistenced to prevent auto-restart
disable_service "nvidia-persistenced"

# Stop all Docker containers if docker is installed
if command -v docker &>/dev/null; then
    CONTAINERS=$(docker ps -aq 2>/dev/null)
    if [[ -n "$CONTAINERS" ]]; then
        log_info "Stopping all Docker containers"
        sudo docker stop $CONTAINERS 2>/dev/null || log_warn "Failed to stop some containers"
        log_success "Docker containers stopped"
    else
        log_info "No Docker containers running"
    fi
else
    log_info "Docker not installed (skipped)"
fi

#############################################
# Step 3: Unload Kernel Modules             #
#############################################

echo ""
log_info "=== Step 3: Unloading kernel modules ==="


log_info "Unloading DRM modules..."
for module in "${DRM_MODULES[@]}"; do
    unload_module "$module"
done

log_info "Unloading NVIDIA modules..."
for module in "${NVIDIA_MODULES[@]}"; do
    unload_module "$module"
done

# Final aggressive cleanup for nvidia driver
log_info "Performing final NVIDIA driver cleanup..."
force_unload_module "nvidia"

# Verify NVIDIA modules are gone
REMAINING_NVIDIA=$(lsmod | grep -i nvidia | wc -l)
if [[ $REMAINING_NVIDIA -eq 0 ]]; then
    log_success "All NVIDIA modules unloaded"
else
    log_warn "$REMAINING_NVIDIA NVIDIA module(s) still loaded:"
    lsmod | grep -i nvidia | awk '{print "  - " $1}'
fi

#############################################
# Step 4: Validate Bond Configuration       #
#############################################

echo ""
log_info "=== Step 4: Validating network configuration ==="

: "${BOND:?Environment variable BOND is not set (e.g. BOND=bond0)}"
: "${IPINT:?Environment variable IPINT is not set (e.g. IPINT=eth0)}"

if ! ip link show "$BOND" >/dev/null 2>&1; then
    log_error "Bond interface '$BOND' does not exist."
    log_info "Available interfaces:"
    ip -br link show | awk '{print "  - " $1}' | grep -v "^  - lo$"
    exit 1
fi

if ! ip link show "$IPINT" >/dev/null 2>&1; then
    log_error "Member interface '$IPINT' does not exist."
    log_info "Available interfaces:"
    ip -br link show | awk '{print "  - " $1}' | grep -v "^  - lo$"
    exit 1
fi

log_success "Bond interface: $BOND"
log_success "Member interface: $IPINT"

#############################################
# Step 5: Get IP from Bond                  #
#############################################

echo ""
log_info "=== Step 5: Extracting IP configuration ==="

# Grab first global IPv4 address in CIDR form, like 192.168.1.10/24
CIDR=$(ip -4 -o addr show dev "$BOND" scope global 2>/dev/null | awk '{print $4}' | head -n1)

if [[ -z "$CIDR" ]]; then
    log_error "No IPv4 address found on $BOND"
    log_info "Current addresses on $BOND:"
    ip addr show dev "$BOND" | grep inet
    exit 1
fi

IP="${CIDR%/*}"
PREFIX="${CIDR#*/}"

log_success "Found IPv4 on $BOND: $IP/$PREFIX"

#############################################
# Step 6: Capture Default Route             #
#############################################

echo ""
log_info "=== Step 6: Capturing default route ==="

DEF_GW=""
DEF_DEV=""

# Get default route (IPv4)
read -r DEF_GW DEF_DEV <<<"$(ip route show default 0.0.0.0/0 2>/dev/null | awk '/default/ {print $3, $5; exit}' || true)"

if [[ -n "$DEF_GW" && -n "$DEF_DEV" ]]; then
    log_success "Current default route: via $DEF_GW dev $DEF_DEV"
    if [[ "$DEF_DEV" == "$BOND" ]]; then
        log_info "Default route uses bond - will migrate to $IPINT"
    fi
else
    log_warn "No default route found (or no IPv4 default)"
fi

#############################################
# Step 7: Break Bond and Move IP            #
#############################################

echo ""
log_info "=== Step 7: Breaking channel bond ==="

log_info "Removing $IPINT from bond master"
sudo ip link set dev "$IPINT" nomaster 2>/dev/null || log_warn "Interface may not have been bonded"

log_info "Bringing up member interface '$IPINT'"
sudo ip link set dev "$IPINT" up || true

log_info "Flushing existing IPs from '$IPINT'"
sudo ip addr flush dev "$IPINT"

log_info "Removing $CIDR from bond '$BOND'"
if sudo ip addr del "$CIDR" dev "$BOND" 2>/dev/null; then
    log_success "IP removed from bond"
else
    log_warn "Failed to remove IP from bond (may already be gone)"
fi

log_info "Assigning $CIDR to member '$IPINT'"
if sudo ip addr add "$CIDR" dev "$IPINT"; then
    log_success "IP assigned to $IPINT"
else
    log_error "Failed to assign IP to $IPINT"
    exit 1
fi

log_info "Ensuring '$IPINT' is up"
sudo ip link set dev "$IPINT" up

#############################################
# Step 8: Remove Bond Interface             #
#############################################

echo ""
log_info "=== Step 8: Removing bond interface ==="

log_info "Bringing bond interface '$BOND' down"
if sudo ip link set dev "$BOND" down 2>/dev/null; then
    log_success "Bond interface down"
else
    log_warn "Failed to bring bond down"
fi

log_info "Deleting bond interface '$BOND'"
if sudo ip link delete "$BOND" type bond 2>/dev/null; then
    log_success "Bond interface deleted"
else
    log_warn "Failed to delete bond interface"
fi

#############################################
# Step 9: Restore Default Route             #
#############################################

echo ""
log_info "=== Step 9: Restoring network connectivity ==="

if [[ -n "$DEF_GW" && "$DEF_DEV" == "$BOND" ]]; then
    log_info "Default route was using $BOND, re-adding via $IPINT"
    
    # First remove any existing default (if still present)
    sudo ip route del default 0.0.0.0/0 2>/dev/null || true
    
    if sudo ip route add default via "$DEF_GW" dev "$IPINT"; then
        log_success "Default route now via $DEF_GW dev $IPINT"
    else
        log_error "Failed to add default route"
        exit 1
    fi
else
    log_info "Default route did not use $BOND or no default route to adjust"
fi

#############################################
# Summary                                   #
#############################################

echo ""
echo "=========================================="
log_success "Node preparation complete!"
echo "=========================================="
echo ""
log_info "Summary:"
log_info "  - Services stopped: ${#SERVICES[@]}"
log_info "  - Kernel modules unloaded: $((${#DRM_MODULES[@]} + ${#NVIDIA_MODULES[@]}))"
log_info "  - Network configuration:"
log_info "      Old: $IP/$PREFIX on $BOND (bond)"
log_info "      New: $IP/$PREFIX on $IPINT (physical)"
if [[ -n "$DEF_GW" ]]; then
    log_info "      Gateway: $DEF_GW"
fi
echo ""
log_success "Node is ready for L11 diagnostics!"
echo ""
