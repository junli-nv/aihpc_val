#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4

timeout 60 bash /home/cmsupport/workspace/sysinfo.sh 2>&1

topdir=/home/cmsupport/workspace

source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
#source /etc/profile
#module load shared
#module load cuda12.8/toolkit/12.8.1
source /home/cmsupport/workspace/cuda/env.sh

hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

cd ${topdir}/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.04.01-archive
source hpc-benchmarks-gpu-env.sh

if [ ${#hosts[*]} -gt 1 ]; then
  export NCCL_MNNVL_ENABLE=1
else
  export NCCL_MNNVL_ENABLE=0
fi

echo "INFO: Doing clean work"
pdsh -R ssh -w ${SLURM_JOB_NODELIST} <<- '_E_'|dshbak -c
enroot list -f|grep pyxis && enroot remove -f $(enroot list -f|grep pyxis) || true
enroot list -f|grep pyxis||true
pkill -9 xhpl &>/dev/null || true
ps -ef|grep xhpl|grep -v -E 'torch|nemo'|grep -v grep || true
sync;sync;sync
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
_E_
echo "INFO: Clean work done"

#eth_nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
eth_nic=enP6p3s0f0np0

set -x
ldd hpl-linux-aarch64-gpu/xhpl
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --map-by ppr:2:socket:PE=36 \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
\
  -x HPL_TEST_SYSTEM=0 \
  -x HPL_CUSOLVER_MP_TESTS=0 \
  -x HPL_USE_NVSHMEM=1 \
  -x NVSHMEM_DISABLE_NVLS=1 \
\
  -x HPL_OOC_MODE=1 \
  -x HPL_EMULATE_DOUBLE_PRECISION=1 \
  -x HPL_DOUBLE_PRECISION_EMULATION_MANTISSA_BIT_COUNT=53 \
  -x MONITOR_GPU=1 \
\
  -x NCCL_NVLS_ENABLE=0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_P2P_LEVEL=NVL \
  -x NCCL_CUMEM_ENABLE=1 \
  -x NCCL_MNNVL_ENABLE=${NCCL_MNNVL_ENABLE} \
  -x NCCL_MIN_CTAS=16 \
  -x NCCL_MNNVL_UUID=0x1969 \
  -x NCCL_IB_DISABLE=1 \
  -x UCX_TLS=tcp \
\
  -x NCCL_SOCKET_IFNAME=${eth_nic} \
  -x UCX_NET_DEVICES=${eth_nic} \
  --mca btl_tcp_if_include ${eth_nic} \
  --mca oob_tcp_if_include ${eth_nic} \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
\
  bash hpl-linux-aarch64-gpu/hpl.sh \
    --no-multinode \
    --gpu-affinity 0:1:2:3 \
    --cpu-affinity 0-35:36-71:72-107:108-143 \
    --mem-affinity 0:0:1:1 \
    --dat ${topdir}/hpl/hpldat/HPL-GB200-${#hosts[*]}N.dat
set +x
