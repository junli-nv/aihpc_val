#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4
#SBATCH --reservation=junli_val
#SBATCH -N 1

timeout 100 bash /home/cmsupport/workspace/sysinfo.sh ${SLURM_JOB_NODELIST} 2>&1
module load slurm

cd ${SLURM_SUBMIT_DIR}

topdir=/home/cmsupport/workspace

source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
source /etc/profile
module load shared
module load cuda12.8/toolkit/12.8.1
source /home/cmsupport/workspace/cuda/env.sh

export LD_LIBRARY_PATH=${topdir}/nccl/bins:$LD_LIBRARY_PATH
export PATH=${topdir}/nccl/bins:$PATH
cd ${topdir}/nccl

hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

export SLURM_CPU_BIND=none
export UCX_TLS=rc_x,cuda
export OMPI_MCA_btl=^openib,smcuda
export NVSHMEM_DISABLE_GDRCOPY=1
export CUDA_MODULE_LOADING=EAGER
export OMPI_MCA_pml=ucx
export UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
export UCX_IB_MMIO_MODE=bf_post_mt
export OMPI_MCA_coll_tuned_bcast_algorithm_segmentsize=4194304
export OMPI_MCA_coll_tuned_bcast_algorithm=3
export OMPI_MCA_coll_tuned_use_dynamic_rules=1
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_MCA_btl_openib_warn_default_gid_prefix=0
export OMPI_MCA_coll_hcoll_enable=0
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
export OMPI_MCA_btl_tcp_if_include=bond0
export NCCL_SOCKET_IFNAME=bond0

export NCCL_DEBUG=INFO
export NCCL_IB_HCA="=mlx5_0,mlx5_1,mlx5_4,mlx5_5"
export NCCL_IB_QPS_PER_CONNECTION=2
export NCCL_IB_SPLIT_DATA_ON_QPS=0

## Only Use IB for communication between GPUs
#export NCCL_CROSS_NIC=0
export NCCL_NVLS_ENABLE=0  #Disable NVLink Sharp
export NCCL_IB_SL=1
export NCCL_P2P_DISABLE=1  #Disable intra-node GPU P2P. It says disable P2P may cause issues on MNNVL machines. Need to check.
export NCCL_SHM_DISABLE=1  #Disable C2C/C-Link. Enable this, 
export NCCL_MNNVL_ENABLE=0 #Disable external NVSwitch

#For gdrdma on GB200:
export NCCL_NET_GDR_LEVEL=SYS
export NCCL_NET_GDR_C2C=1

cd ${SLURM_SUBMIT_DIR}
eth_nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
set -x
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  -x NCCL_SOCKET_IFNAME=${eth_nic} \
  --mca btl_tcp_if_include ${eth_nic} \
  --mca oob_tcp_if_include ${eth_nic} \
  --map-by ppr:2:socket:PE=36 \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
  ${topdir}/nccl/bins/all_reduce_perf -b 16G -f 2 -g 1 -e 16G --iters 20
set +x