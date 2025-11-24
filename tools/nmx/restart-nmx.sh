#!/bin/bash

nvsw01=GB200-DH420-P2-C01-NVSW-01
user='admin'
passwd='Nvidia@123'

restart_nmx=$(mktemp)
cat > ${restart_nmx} <<- 'EOF'
#!/bin/bash
set -ex

# Check current status
nv show cluster apps

# Enable cluster serivce
nv set cluster state enabled

# Apply NVSW setting
nv config apply

# Save NVSW setting
nv config save

# Generate the nmx-controller config file
nv action generate sdn config app nmx-controller type fm_config

# Find the nmx-controller config file
f=$(nv show sdn config app nmx-controller type fm_config files | grep nmx-controller_fm_config | tail -n 1 | awk '{print $NF}')
echo $f

# Edit the generated nmx-controller configure file. Makre sure the MNNVL_TOPOLOGY=gb200_nvl72r1_c2g4_topology
sudo sed -i -e 's#MNNVL_TOPOLOGY=#MNNVL_TOPOLOGY=gb200_nvl72r1_c2g4_topology#g' $f
grep MNNVL_TOPOLOGY $f

# Install the config file
nv action install sdn config app nmx-controller type fm_config files $f

# Stop the nmx-controller service
nv action stop cluster apps nmx-controller

# Restart the nmx-controller service
nv action start cluster apps nmx-controller

# Check the nmx-controller setting(It needs to wait 30 seconds after restarting service)
sleep 30
nv show cluster app running

exit 0
EOF

# Upload the script to nvswitch
sshpass -p "${passwd}" /usr/bin/scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no \
  ${restart_nmx} ${user}@${nvsw01}:/tmp/restart_nmx.sh
rm -f ${restart_nmx}

# Run the script
sshpass -p "${passwd}" /usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no \
  ${user}@${nvsw01} bash /tmp/restart_nmx.sh

# Please enable only one NVSW of the rack enable the nmx-controller service**
# All the left should say "No Data", if not disable the ones.
for i in {02..09}; do
sshpass -p "${passwd}" /usr/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no ${user}@${nvsw01%%-01}-${i} "hostname; nv set cluster state disabled; nv config apply; nv config save; nv show cluster app running"
done

# Check the P2P on compute trays again to see whether the P2P is enabled
# nvidia-smi topo -p2p n

