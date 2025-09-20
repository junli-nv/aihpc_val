#!/bin/bash
#
# Parameters
#SBATCH --account=root
#SBATCH --exclusive
#SBATCH --job-name=nemotron4_340b_pretrain
#SBATCH --mem=0
#SBATCH --ntasks-per-node=4
#SBATCH --open-mode=append
#SBATCH --partition=defq
#SBATCH --time=00:13:00
#SBATCH --gpus-per-node=4
#SBATCH --reservation=junli_val

set -x

#CONT=/home/cmsupport/workspace/nemo/nemo-25.04.rc2.sqsh
#CONT=/raid/data/nemo-25.04.rc2.sqsh
#CONT=/raid/data/nemo-25.04.rc2.m1.sqsh
#CONT=/raid/data/nemo-25.04.rc2.m2.sqsh
CONT=/data/nemo-25.04.rc2.m2.sqsh

case ${SLURM_NNODES} in
  16)                single_rack=1 ;;
  32|64|128|256|480|512|560) single_rack=0 ;;
  *)                 echo "ERROR: SLURM_NNODES=$SLURM_NNODES not 16/32/64/128/256/480/512/560"; exit 1 ;;
esac
CASE=$PWD/configs/gb200/pretrain_nemotron4_340b_bf16_${SLURM_NNODES}nodes_tp4_pp8_cp1_vp12_1mbs_${SLURM_NNODES}gbs_fn_or_script

cd ${SLURM_SUBMIT_DIR}

export PYTHONUNBUFFERED=1
export SLURM_UNBUFFEREDIO=1
export TORCHX_MAX_RETRIES=0

nodes=( $( scontrol show hostnames $SLURM_JOB_NODELIST ) )
nodes_array=($nodes)
head_node=${nodes_array[0]}
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address)

export TORCH_NCCL_AVOID_RECORD_STREAMS=1
export TRANSFORMERS_OFFLINE=1
export TOKENIZERS_PARALLELISM=False
export NCCL_NVLS_ENABLE=0
export NVTE_FLASH_ATTN=1
export NVTE_FUSED_ATTN=1
export NEMO_LOG_MEMORY_USAGE=1
export NEMORUN_HOME=$PWD
export NEMO_HOME=$PWD
#export NVTE_NORM_FWD_USE_CUDNN=1
#export NVTE_NORM_BWD_USE_CUDNN=1
export CUDA_DEVICE_MAX_CONNECTIONS=32
export NVTE_FWD_LAYERNORM_SM_MARGIN=16
export NVTE_BWD_LAYERNORM_SM_MARGIN=16
export NCCL_P2P_NET_CHUNKSIZE=2097152

#nic=$(/usr/sbin/ip r sh|grep default|awk '{print $5}')
#nic=enP5p9s0
nic=enP6p3s0f0np0
if [ ${single_rack} -eq 1 ]; then
  export NCCL_DEBUG=INFO
  export NCCL_P2P_LEVEL=NVL
  export NCCL_CUMEM_ENABLE=1
  export NCCL_MNNVL_ENABLE=1
  export NCCL_MIN_CTAS=16
  export NCCL_MNNVL_UUID=0x1969
  export NCCL_IB_DISABLE=1
  export UCX_TLS=tcp
  export UCX_NET_DEVICES=${nic}
  export NCCL_SOCKET_IFNAME=${nic}
  export OMPI_MCA_btl_tcp_if_include=${nic}
  export OMPI_MCA_oob_tcp_if_include=${nic}
else
  export NCCL_DEBUG=INFO
  export NCCL_SOCKET_IFNAME=${nic}
  export OMPI_MCA_btl_tcp_if_include=${nic}
  export OMPI_MCA_oob_tcp_if_include=${nic}
  #
  export NCCL_MNNVL_ENABLE=1
  export NCCL_IB_HCA="=mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1"
  export UCX_NET_DEVICES=mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1
  export UCX_TLS=rc
  #
  export NCCL_P2P_LEVEL=NVL
  export NCCL_NVLS_ENABLE=1
  export NCCL_CUMEM_ENABLE=1
  export NCCL_MIN_CTAS=16
  #
  #export NCCL_NET_GDR_LEVEL=SYS ## Need check
fi

echo
echo "NODELIST: ${SLURM_JOB_NODELIST}"
echo

s_time=$(date +%s)
echo "INFO: cleaning work begin"
pdsh -R ssh -w ${SLURM_JOB_NODELIST} <<- 'EOF'|dshbak -c
pkill -9 python &>/dev/null || true
ps -ef|grep python|grep -E 'torch|nemo'|grep -v grep || true
enroot list -f|grep pyxis && enroot remove -f $(enroot list -f|grep pyxis) || true
rm -f /var/lib/systemd/coredump/* &>/dev/null || true
EOF
echo "INFO: cleaning work done"

timelimit=$[(SLURM_JOB_END_TIME-SLURM_JOB_START_TIME-200)]
timeout 100 bash $PWD/sysinfo.sh 2>&1

#export ENROOT_CONNECT_TIMEOUT=600
#export ENROOT_TRANSFER_TIMEOUT=12000

export NCCL_DEBUG=WARN
   #  --container-name=nemo \
srun --export=ALL \
  --container-writable \
  --container-image "${CONT}" \
  --container-workdir /opt/NeMo \
  --container-mounts /dev/:/dev,$PWD:$PWD \
  --wait=120 --kill-on-bad-exit=1 --mpi=pmix \
  bash $PWD/wrapper.sh \
  all_reduce_perf_mpi -b 16G -f 2 -g 1 -e 16G
exitcode=$?
if [ $exitcode -ne 0 ]; then
  exit 1
fi

export NCCL_DEBUG=INFO
srun --export=ALL \
  --container-writable \
  --container-image "${CONT}" \
  --container-mounts /dev/:/dev,$PWD:$PWD \
  --container-workdir /opt/NeMo \
  --wait=120 --kill-on-bad-exit=1 --mpi=pmix \
  bash $PWD/wrapper.sh \
  python -m nemo_run.core.runners.fdl_runner -n $(basename ${CASE}|sed -e 's:_fn_or_script::g') ${CASE}
exitcode=$?
set +x
e_time=$(date +%s)
echo "INFO: timelimit=${timelimit}(s), real_took=$[e_time-s_time](s)"

#echo "job exited with code $exitcode"
#if [ $exitcode -ne 0 ]; then
#    if [ "$TORCHX_MAX_RETRIES" -gt "${SLURM_RESTART_COUNT:-0}" ]; then
#        scontrol requeue "$SLURM_JOB_ID"
#    fi
#    exit $exitcode
#fi

