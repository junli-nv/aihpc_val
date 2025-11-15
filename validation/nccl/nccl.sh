#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4
#SBATCH -N 30
#SBATCH -w s03-p1-dgx-01-c[02-03,05-12,14-18],s04-p1-dgx-02-c[01-09,11-13,16-18]

cd $SLURM_SUBMIT_DIR
source ../envs/global_env.sh
timeout 100 bash ../../tools/hc/sysinfo.sh 2>&1

hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

set -x
ldd `which all_reduce_perf`
nic=bond0
#nic=enP5p9s0
#nic=enP6p3s0f0np0
UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
NCCL_IB_HCA="=mlx5_0,mlx5_1,mlx5_4,mlx5_5"

mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --mca btl_tcp_if_include ${nic} \
  --mca oob_tcp_if_include ${nic} \
  --map-by ppr:2:socket:PE=36 \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  -x NCCL_NVLS_ENABLE=1 \
  -x NCCL_CUMEM_ENABLE=1 \
  -x NCCL_CUMEM_HOST_ENABLE=0 \
  -x NCCL_MNNVL_ENABLE=1 \
  -x NCCL_MIN_CTAS=16 \
\
  -x NCCL_P2P_LEVEL=C2C \
  -x NCCL_NET_GDR_C2C=1 \
  -x NCCL_NET_GDR_LEVEL=SYS \
  -x NCCL_RUNTIME_CONNECT=0 \
\
  -x NCCL_DEBUG=INFO \
\
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  -x OMPI_MCA_btl_openib_warn_default_gid_prefix=0 \
  -x OMPI_MCA_coll_hcoll_enable=0 \
\
  -x SLURM_CPU_BIND=none \
  -x OMPI_MCA_pml=ucx \
  -x UCX_NET_DEVICES="${UCX_NET_DEVICES}" \
  -x UCX_TLS=rc_x,cuda \
  -x OMPI_MCA_btl=^openib,smcuda \
  -x NCCL_SOCKET_IFNAME=${nic} \
  -x NCCL_IB_HCA="${NCCL_IB_HCA}" \
\
  -x NCCL_IB_QPS_PER_CONNECTION=2 \
  -x NCCL_IB_SPLIT_DATA_ON_QPS=0 \
\
  -x NVSHMEM_DISABLE_GDRCOPY=1 \
  -x CUDA_MODULE_LOADING=EAGER \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
  bash ${SLURM_SUBMIT_DIR}/wrapper.sh \
  `which all_reduce_perf` -b 16G -f 2 -g 1 -e 16G --iters 50
set +x
