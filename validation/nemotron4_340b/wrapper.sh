#!/bin/bash
#
#
##ulimit -s 8192 #<-- ONLY needed by NCCL 2.27.x but not work well with Nemotron340B
ulimit -l unlimited
export CUDA_DEVICE_ORDER=PCI_BUS_ID
#cmd="numactl --cpunodebind=$[SLURM_LOCALID/4] --membind=$[SLURM_LOCALID/4] $@"
cmd="numactl --cpunodebind=$[SLURM_LOCALID/2] --membind=$[SLURM_LOCALID/2] $@"
echo "HOST=$(hostname), RANK=${SLURM_PROCID}, LOCAL_RANK=${SLURM_LOCALID}, NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME}, CMD=${cmd}"
eval ${cmd}
