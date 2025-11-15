#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=144
#SBATCH --gpus-per-node=4
#SBATCH -N 1

cd $SLURM_SUBMIT_DIR
source ../envs/global_env.sh
#timeout 60 bash ../../tools/hc/sysinfo.sh 2>&1

hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

set -x
ldd ${HPL_HOME}/hpl-linux-aarch64-gpu/xhpl
export HPL_TEST_SYSTEM=0
export HPL_CUSOLVER_MP_TESTS=0
export HPL_USE_NVSHMEM=1
export NVSHMEM_DISABLE_NVLS=1
export HPL_OOC_MODE=1
export HPL_EMULATE_DOUBLE_PRECISION=1
export HPL_DOUBLE_PRECISION_EMULATION_MANTISSA_BIT_COUNT=53
export MONITOR_GPU=1
export NCCL_NVLS_ENABLE=0
export NCCL_DEBUG=WARN
export NCCL_P2P_LEVEL=NVL
export NCCL_CUMEM_ENABLE=1
export NCCL_MNNVL_ENABLE=0
export NCCL_MIN_CTAS=16
export NCCL_MNNVL_UUID=0x1969
export NCCL_IB_DISABLE=1
export UCX_TLS=tcp

ipmitool raw 0x3c 0x74 100
pkill -9 xhpl &>/dev/null || true
rm -f /var/lib/systemd/coredump/* &>/dev/null || true
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
sysctl -w kernel.numa_balancing=0
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled
cpupower frequency-set -g performance
s0=$(cat /sys/devices/system/cpu/cpu{0..71}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{print int(sum/NR/1000)}')
s1=$(cat /sys/devices/system/cpu/cpu{72..143}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{print int(sum/NR/1000)}')
echo $s0 $s1
nvidia-smi -pm 1
nvidia-smi -rac
nvidia-smi -rgc
#nvidia-smi -lmcd ${ret[0]}
ret=($(nvidia-smi -i 0 --query-supported-clocks=mem,gr --format=csv | head -n 2 | tail -n 1 | awk '{print $1, $3}'))
nvidia-smi -ac ${ret[0]},${ret[1]}
nvidia-smi -lgc ${ret[1]},${ret[1]}
sleep 3
nvidia-smi --format=csv --query-gpu gpu_bus_id,gpu_name,compute_mode,ecc.mode.current,clocks.gr,clocks.max.gr,clocks.sm,clocks.max.sm,clocks.max.mem,clocks.video,clocks.applications.gr,clocks.applications.mem,clocks.default_applications.gr,clocks.default_applications.mem,pstate,power.default_limit

echo "GPU=0"
bash ${HPL_HOME}/hpl-linux-aarch64-gpu/hpl.sh \
  --no-multinode \
  --gpu-affinity 0 \
  --cpu-affinity 0-35 \
  --mem-affinity 0 \
  --dat ./hpldat/HPL-GB200-1GPU.dat
echo "GPU=1"
bash ${HPL_HOME}/hpl-linux-aarch64-gpu/hpl.sh \
  --no-multinode \
  --gpu-affinity 1 \
  --cpu-affinity 36-71 \
  --mem-affinity 0 \
  --dat ./hpldat/HPL-GB200-1GPU.dat
echo "GPU=2"
bash ${HPL_HOME}/hpl-linux-aarch64-gpu/hpl.sh \
  --no-multinode \
  --gpu-affinity 2 \
  --cpu-affinity 72-107 \
  --mem-affinity 1 \
  --dat ./hpldat/HPL-GB200-1GPU.dat
echo "GPU=3"
bash ${HPL_HOME}/hpl-linux-aarch64-gpu/hpl.sh \
  --no-multinode \
  --gpu-affinity 3 \
  --cpu-affinity 108-143 \
  --mem-affinity 1 \
  --dat ./hpldat/HPL-GB200-1GPU.dat
set +x
