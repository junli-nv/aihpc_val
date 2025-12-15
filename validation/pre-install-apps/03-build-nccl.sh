#!/bin/bash

########### Compile NCCL
topdir=/home/cmsupport/workspace
mkdir -p ${topdir}
cd ${topdir}

# https://developer.nvidia.com/networking/hpc-x
## CUDA 12
wget https://content.mellanox.com/hpc/hpc-x/v2.22.1rc4/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64.tbz
tar xjvf hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64.tbz
source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh

## CUDA 13
# wget https://content.mellanox.com/hpc/hpc-x/v2.25.1_cuda13/hpcx-v2.25.1-gcc-doca_ofed-ubuntu24.04-cuda13-aarch64.tbz
# tar xjvf hpcx-v2.25.1-gcc-doca_ofed-ubuntu24.04-cuda13-aarch64.tbz

hpcx_load
source /etc/profile
source /home/cmsupport/workspace/cuda/env.sh

## Compile NCCL
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
#git checkout v2.27.6-1
git checkout v2.28.3-1
make -j src.build
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
make -j MPI=1 MPI_HOME=${OMPI_HOME} NCCL_HOME=$PWD/../build

cp -arv build/ ../bins
cd ../bins/
rm -fr *.o verifiable
cp -arv ../build/lib/libnccl*so* .

########### Check NCCL binary
topdir=/home/cmsupport/workspace
source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
source ${topdir}/cuda/env.sh
export LD_LIBRARY_PATH=${topdir}/nccl/bins:$LD_LIBRARY_PATH
export PATH=${topdir}/nccl/bins:$PATH

ldd `which all_reduce_perf`
