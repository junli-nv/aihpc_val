#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4

timeout 60 bash /home/cmsupport/workspace/sysinfo.sh ${SLURM_JOB_NODELIST} 2>&1

topdir=/home/cmsupport/workspace

source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
source /etc/profile
module load shared
module load cuda12.8/toolkit/12.8.1

export LD_LIBRARY_PATH=${topdir}/nccl/bins:$LD_LIBRARY_PATH
export PATH=${topdir}/nccl/bins:$PATH
cd ${topdir}/nccl

hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

if [ ${#hosts[*]} -gt 1 ]; then
  export NCCL_MNNVL_ENABLE=1
else
  export NCCL_MNNVL_ENABLE=0
fi

set -x
ldd `which all_reduce_perf`

eth_nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
export UCX_NET_DEVICES=${eth_nic}
export NCCL_SOCKET_IFNAME=${eth_nic}

#ulimit -s 8192 -> workaround segment fault start with 2.27.x 
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --map-by ppr:2:socket:PE=36 \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
\
  -x NCCL_NVLS_ENABLE=1 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_P2P_LEVEL=NVL \
  -x NCCL_CUMEM_ENABLE=1 \
  -x NCCL_MNNVL_ENABLE=${NCCL_MNNVL_ENABLE} \
  -x NCCL_MIN_CTAS=16 \
  -x NCCL_MNNVL_UUID=0x1969 \
  -x NCCL_IB_DISABLE=1 \
  -x UCX_TLS=tcp \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
  bash -c "ulimit -s 8192; all_reduce_perf -b 8 -f 2 -g 1 -e 16G -R 0"
set +x
