#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4

#timeout 90 bash /home/cmsupport/workspace/sysinfo.sh 2>&1

topdir=/home/cmsupport/workspace
CONT=/data/hpc-benchmarks-25.04.sqsh

echo "NODELIST=${SLURM_JOB_NODELIST}"
hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

if [ ${#hosts[*]} -gt 1 ]; then
  export NCCL_MNNVL_ENABLE=1
else
  export NCCL_MNNVL_ENABLE=0
fi

#if [ ${#hosts[*]} -ge 128 ]; then
if [ ${#hosts[*]} -ge 512 ]; then
  export HPL_USE_NVSHMEM=0
else
  export HPL_USE_NVSHMEM=1
  export HPL_P2P_AS_BCAST=4 #(0->ncclBcast, 1->ncclSend / Recv, 2->CUDA - aware MPI, 3->host MPI, 4->NVSHMEM)
fi

echo "INFO: Doing clean work"
pdsh -R ssh -w ${SLURM_JOB_NODELIST} <<- '_E_'|dshbak -c
pkill -9 xhpl || true
echo 3 > /proc/sys/vm/drop_caches
_E_
echo "INFO: Clean work done"

#eth_nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
eth_nic=enP6p3s0f0np0

export  MELLANOX_VISIBLE_DEVICES=all

export  HPL_TEST_SYSTEM=0
export  HPL_CUSOLVER_MP_TESTS=0
export  HPL_OOC_MODE=0
export  HPL_EMULATE_DOUBLE_PRECISION=1
export  HPL_DOUBLE_PRECISION_EMULATION_MANTISSA_BIT_COUNT=53
export  MONITOR_GPU=1
 
#export NCCL_IB_TIMEOUT=10
#export NCCL_IB_RETRY_CNT=1

export  HPL_USE_NVSHMEM=${HPL_USE_NVSHMEM}
export  NVSHMEM_DISABLE_NVLS=1
export  NVSHMEM_HCA_LIST="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
export  NVSHMEM_ENABLE_NIC_PE_MAPPING=1
 
export  NCCL_NVLS_ENABLE=0
export  NCCL_DEBUG=INFO
export  NCCL_P2P_LEVEL=C2C
export  NCCL_CUMEM_ENABLE=1
export  NCCL_CUMEM_HOST_ENABLE=0
export  NCCL_MNNVL_ENABLE=${NCCL_MNNVL_ENABLE}
export  NCCL_MIN_CTAS=16
export  NCCL_NET_GDR_LEVEL=SYS
export  SLURM_CPU_BIND=none
export  OMPI_MCA_pml=ucx
export  UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
export  UCX_TLS=rc
export  OMPI_MCA_btl=^openib,smcuda
export  NCCL_IB_HCA="=mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
 
export  NVSHMEM_DISABLE_GDRCOPY=1
export  CUDA_MODULE_LOADING=EAGER
 
export  NCCL_SOCKET_IFNAME=${eth_nic}
export  MCA_btl_tcp_if_include=${eth_nic}
export  MCA_oob_tcp_if_include=${eth_nic}

#  -x NCCL_IB_QPS_PER_CONNECTION=2
#  -x NCCL_IB_SPLIT_DATA_ON_QPS=0

set -x

export NCCL_DEBUG=INFO
srun --export=ALL \
  --wait=120 --kill-on-bad-exit=1 --mpi=pmix \
  --container-writable \
  --container-image "${CONT}" \
  --container-mounts /dev/:/dev,$PWD:$PWD,${topdir}:${topdir} \
  /workspace/hpl.sh \
    --gpu-affinity 0:1:2:3 \
    --cpu-affinity 0-35:36-71:72-107:108-143 \
    --mem-affinity 0:0:1:1 \
    --ucx-affinity mlx5_0:mlx5_1:mlx5_4:mlx5_5 \
    --dat ${topdir}/hpl/hpldat/HPL-GB200-${#hosts[*]}N.dat
set +x
