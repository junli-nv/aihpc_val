#!/bin/bash

apt-get install -y --no-install-recommends libboost-program-options-dev cmake

topdir=/home/cmsupport/workspace
mkdir -p ${topdir}
source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
source /etc/profile
source /home/cmsupport/workspace/cuda/env.sh

cd ${topdir}
git clone https://github.com/NVIDIA/nvbandwidth
cd nvbandwidth
## Build for single node version
cmake -LH .
make -j VERBOSE=1
mv nvbandwidth nvbandwidth.SN
## Build for multiple node version
make clean
cmake -DMULTINODE=1 -LH .
make -j VERBOSE=1
mv nvbandwidth nvbandwidth.MN

cd ${topdir}
git clone https://github.com/NVIDIA/nvloom.git
cd nvloom/
cmake -LH .
make -j VERBOSE=1
