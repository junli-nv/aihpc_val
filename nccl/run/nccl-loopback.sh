#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4
#SBATCH -N 1

#timeout 100 bash /home/cmsupport/workspace/sysinfo.sh ${SLURM_JOB_NODELIST} 2>&1
module load slurm

cd ${SLURM_SUBMIT_DIR}

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

## Only Use IB for communication between GPUs
export UCX_TLS=tcp
export NCCL_DEBUG=INFO
export NCCL_NVLS_ENABLE=0  #Disable NVLink Sharp
export NCCL_IB_SL=1
export NCCL_P2P_DISABLE=1  #Disable intra-node GPU P2P. It says disable P2P may cause issues on MNNVL machines. Need to check.
export NCCL_SHM_DISABLE=1  #Disable C2C/C-Link. Enable this,
export NCCL_MNNVL_ENABLE=0 #Disable external NVSwitch
export NCCL_IB_HCA="=mlx5_0,mlx5_1,mlx5_4,mlx5_5"

#export NCCL_IB_QPS_PER_CONNECTION=2
#export NCCL_IB_SPLIT_DATA_ON_QPS=0
#export NCCL_NET_GDR_LEVEL=SYS
#export NCCL_NET_GDR_C2C=1
#export NCCL_CROSS_NIC=0

eth_nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
export UCX_NET_DEVICES=${eth_nic}
export NCCL_SOCKET_IFNAME=${eth_nic}
set -x
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --mca btl_tcp_if_include ${eth_nic} \
  --mca oob_tcp_if_include ${eth_nic} \
  --map-by ppr:2:socket:PE=36 \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
  bash -c "ulimit -s 8192; ${topdir}/nccl/bins/all_reduce_perf -b 16G -f 2 -g 1 -e 16G --iters 100"
set +x
