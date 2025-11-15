#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4

cd $SLURM_SUBMIT_DIR
source ../envs/global_env.sh
timeout 60 bash ../../tools/hc/sysinfo.sh 2>&1

echo "NODELIST=${SLURM_JOB_NODELIST}"
hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

#if [ ${#hosts[*]} -gt 1 ]; then
#  export NCCL_MNNVL_ENABLE=1
#else
#  export NCCL_MNNVL_ENABLE=0
#fi
## GPU residual issue will make HPL become hang with NCCL_MNNVL_ENABLE=1
## For simplify the test, set NCCL_MNNVL_ENABLE=0 instead.
export NCCL_MNNVL_ENABLE=0

if [ ${#hosts[*]} -ge 512 ]; then
  export HPL_USE_NVSHMEM=0
  export HPL_OOC_MODE=1
else
  export HPL_OOC_MODE=0
  export HPL_USE_NVSHMEM=1
  export HPL_P2P_AS_BCAST=4 #(0->ncclBcast, 1->ncclSend / Recv, 2->CUDA - aware MPI, 3->host MPI, 4->NVSHMEM)
fi

export HPL_EMULATE_DOUBLE_PRECISION=1
#export NCCL_IB_TIMEOUT=25
#export NCCL_IB_RETRY_CNT=10
#export NCCL_PATH=/home/cmsupport/workspace/nccl/bins
#export LD_LIBRARY_PATH=$NCCL_PATH:$LD_LIBRARY_PATH

echo "INFO: Doing clean work"
pdsh -R ssh -w ${SLURM_JOB_NODELIST} <<- '_E_'|dshbak -c
pkill -9 xhpl || true
echo 3 > /proc/sys/vm/drop_caches
_E_
echo "INFO: Clean work done"

#eth_nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
#eth_nic=enP6p3s0f0np0
#eth_nic=ibp3s0
eth_nic=bond0

NVSHMEM_HCA_LIST="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
NCCL_IB_HCA="=mlx5_0,mlx5_1,mlx5_4,mlx5_5"

#\
#  -x NCCL_IB_QPS_PER_CONNECTION=2 \
#  -x NCCL_IB_SPLIT_DATA_ON_QPS=0 \
#  -x UCX_TLS=rc_x,cuda \

set -x
ldd ${HPL_HOME}/hpl-linux-aarch64-gpu/xhpl
# NCCL_DEBUG_SUBSYS=ALL \
  #--display-map --display-topo --report-bindings \
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --map-by ppr:2:socket:PE=36 \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
\
  -x OMPI_MCA_btl_openib_warn_default_gid_prefix=0 \
  -x OMPI_MCA_coll_hcoll_enable=0 \
\
  -x HPL_TEST_SYSTEM=0 \
  -x HPL_CUSOLVER_MP_TESTS=0 \
  -x HPL_OOC_MODE=${HPL_OOC_MODE} \
  -x HPL_EMULATE_DOUBLE_PRECISION=${HPL_EMULATE_DOUBLE_PRECISION} \
  -x HPL_DOUBLE_PRECISION_EMULATION_MANTISSA_BIT_COUNT=53 \
  -x MONITOR_GPU=1 \
\
  -x HPL_USE_NVSHMEM=${HPL_USE_NVSHMEM} \
  -x NVSHMEM_DISABLE_NVLS=1 \
  -x NVSHMEM_HCA_LIST="${NVSHMEM_HCA_LIST}" \
  -x NVSHMEM_ENABLE_NIC_PE_MAPPING=1 \
\
  -x NCCL_NVLS_ENABLE=0 \
  -x NCCL_DEBUG=INFO \
  -x NCCL_P2P_LEVEL=C2C \
  -x NCCL_CUMEM_ENABLE=1 \
  -x NCCL_CUMEM_HOST_ENABLE=0 \
  -x NCCL_MNNVL_ENABLE=${NCCL_MNNVL_ENABLE} \
  -x NCCL_MIN_CTAS=16 \
  -x NCCL_NET_GDR_LEVEL=SYS \
\
  -x SLURM_CPU_BIND=none \
  -x OMPI_MCA_pml=ucx \
  -x UCX_NET_DEVICES="${UCX_NET_DEVICES}" \
  -x UCX_TLS=rc \
  -x OMPI_MCA_btl=^openib,smcuda \
  -x NCCL_IB_HCA="${NCCL_IB_HCA}" \
\
  -x NCCL_SOCKET_IFNAME=${eth_nic} \
  --mca btl_tcp_if_include ${eth_nic} \
  --mca oob_tcp_if_include ${eth_nic} \
\
  -x NVSHMEM_DISABLE_GDRCOPY=1 \
  -x CUDA_MODULE_LOADING=EAGER \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
\
  bash ${HPL_HOME}/hpl-linux-aarch64-gpu/hpl.sh \
    --gpu-affinity 0:1:2:3 \
    --cpu-affinity 0-35:36-71:72-107:108-143 \
    --mem-affinity 0:0:1:1 \
    --dat ./hpldat/HPL-GB200-${#hosts[*]}N.dat
set +x
