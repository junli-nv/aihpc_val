#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4
#SBATCH --time=00:100:00
#SBATCH -N 1

module load slurm
cd ${SLURM_SUBMIT_DIR}

topdir=/home/cmsupport/workspace

source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64//hpcx-mt-init-ompi.sh
hpcx_load
export CUDA_HOME=${topdir}/cuda12
export NCCL_PATH=${topdir}/nccl_2.28.9-1+cuda12.9_aarch64
export PATH=${CUDA_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${NCCL_PATH}/lib:.:${LD_LIBRARY_PATH}

echo "NODELIST=$SLURM_JOB_NODELIST"
hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

nic=bond0

## Ref: https://confluence.nvidia.com/pages/viewpage.action?spaceKey=DCGM&title=Mndiag+and+mnubergemm+testing+on+GB200+Colorado+%28Equinix%29+cluster+8x+NVL72
#mnubergemm's variables
#https://nvbugspro.nvidia.com/bug/5634196
#https://nvbugspro.nvidia.com/bug/5554973
duration_sec=$[SLURM_JOB_END_TIME-SLURM_JOB_START_TIME-300]
[ $duration_sec -le 0 ] && duration_sec=86000
STD="--dynamic_adj --MM_max_workload 65536 --max_workload 65536 --time_to_run ${duration_sec} --workload GNC"
MM="--MM_M 0 --MM_N 4096 --MM_sm_count 112 --MM_type SX_SX_SSS —MM_force_cublas_algo SQAAABQAAAAiAAAAAQAAAAAAAAAAAAAAAAAAAAAACQAAAAAARdgBAAAAAAAAAAAAAAAAAE0AAAAAAAAAAAAAAA=="
NET="--NET_sm_count 32 --NET_link_order scatter_sum --NET_size 20480000"
CE="--CE_type H --CE_size 2048000"
FREQQ="--freq 400 --duty 0.9 --dual_mode --dual_freq 0.0025 --dual_duty 0.75 --tri_mode --tri_duty 0.05"

set -x
#1. Check nodes status
timeout 120 bash ${topdir}/aihpc_val/tools/hc/sysinfo.sh
#2. Run mnubergemm
ldd ./mnubergemm
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
  -x NCCL_CUMEM_HOST_ENABLE=0 \
  -x NCCL_MNNVL_ENABLE=1 \
  -x NCCL_MIN_CTAS=64 \
  -x NCCL_IB_DISABLE=1 \
  -x UCX_TLS=tcp \
\
  --mca btl_tcp_if_include ${nic} \
  --mca oob_tcp_if_include ${nic} \
  -x NCCL_SOCKET_IFNAME=${nic} \
  -x UCX_NET_DEVICES=${nic} \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',') \
  -np $[4*${#hosts[*]}] \
  ./mnubergemm ${STD} ${FREQQ} ${MM} ${NET} ${CE}
#3. Check nodes' healthiness, drain if any issue found
pdsh -R ssh -f 32 -w $(echo ${hosts[*]} | tr ' ' ',') <<- EOF
${PWD}/../../tools/hc/checker.sh -e|grep -v PASS||true
EOF
set +x

# export MELLANOX_VISIBLE_DEVICES=all
# CONT=/raid/data/nvidian+nvis+mnubergemm+tensorrt-25.08-v1.12.1-arm.sqsh
# srun --cpu-bind=none --mpi=pmix --container-image="$CONT" ./mnubergemm ${STD} ${FREQQ} ${MM} ${NET} ${CE}
