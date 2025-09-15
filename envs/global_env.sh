#!/bin/bash

module load slurm

export topdir=/home/cmsupport/workspace

#HPCX
source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load

#CUDA
# source /etc/profile
# module load shared
# module load cuda12.8/toolkit/12.8.1
export CUDA_HOME=/home/cmsupport/workspace/cuda
export PATH=${CUDA_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

#NCCL
export NCCL_PATH=${topdir}/nccl/bins
export LD_LIBRARY_PATH=${NCCL_PATH}:$LD_LIBRARY_PATH
export PATH=${NCCL_PATH}:$PATH
