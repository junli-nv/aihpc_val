#!/bin/bash
source /etc/profile
module load shared
module load slurm

export topdir=/home/cmsupport/workspace

#HPCX
#HPCX_HOME=${topdir}/hpcx-v2.24.1-gcc-doca_ofed-ubuntu24.04-cuda13-aarch64
HPCX_HOME=${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64
source ${HPCX_HOME}/hpcx-mt-init-ompi.sh
hpcx_load

#CUDA
export CUDA_HOME=/home/cmsupport/workspace/cuda
export PATH=${CUDA_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

#NCCL
export NCCL_PATH=${topdir}/nccl/bins
export LD_LIBRARY_PATH=${NCCL_PATH}:$LD_LIBRARY_PATH
export PATH=${NCCL_PATH}:$PATH

#HPL
## Workaround (Segmentation fault: address not mapped to object at address 0xffffff7fffc0) issue
#export NCCL_PATH=${topdir}/nccl
#export HPL_HOME=${topdir}/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.09.06-archive/cuda13
export HPL_HOME=${topdir}/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.04.01-archive

#NVSHMEM
#export NVSHMEM_HOME=${topdir}/libnvshmem-linux-sbsa-3.4.5_cuda13-archive
#export PATH=${NVSHMEM_HOME}/bin:${PATH}
#export LD_LIBRARY_PATH=${NVSHMEM_HOME}/lib:${LD_LIBRARY_PATH}
