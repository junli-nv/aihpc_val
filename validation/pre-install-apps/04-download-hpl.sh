#!/bin/bash

########### Download HPL binaries
topdir=/home/cmsupport/workspace
mkdir -p ${topdir}
cd ${topdir}

#URL: https://developer.nvidia.com/nvidia-hpc-benchmarks-downloads?target_os=Linux&target_arch=arm64-sbsa&Compilation=Native&Distribution=Agnostic&Implementation=OpenMPI
wget https://developer.download.nvidia.com/compute/nvidia-hpc-benchmarks/redist/nvidia_hpc_benchmarks_openmpi/linux-sbsa/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.04.01-archive.tar.xz
tar -xJvf nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.04.01-archive.tar.xz

# wget https://developer.download.nvidia.com/compute/nvidia-hpc-benchmarks/redist/nvidia_hpc_benchmarks_openmpi/linux-sbsa/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.09.06-archive.tar.xz
# tar -xJvf nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.09.06-archive.tar.xz

########### Check HPL binary
topdir=/home/cmsupport/workspace
source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
source ${topdir}/cuda/env.sh
source ${topdir}/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.04.01-archive/hpc-benchmarks-gpu-env.sh

ldd ${topdir}/nvidia_hpc_benchmarks_openmpi-linux-sbsa-25.04.01-archive/hpl-linux-aarch64-gpu/xhpl
