#!/bin/bash
topdir=/home/cmsupport/workspace/
cd ${topdir}

## Method1:
##NCCL: https://developer.nvidia.com/nccl/nccl-download
wget -c 'https://developer.download.nvidia.com/compute/machine-learning/nccl/secure/2.28.9/agnostic/aarch64sbsa/nccl_2.28.9-1%2Bcuda12.9_aarch64.txz?__token__=exp=1764753523~hmac=5480d4624e9aa336788fe4b8a32a5048c1ed6e20a418225bdae41e2ab74fdc8d&t=eyJscyI6ImdzZW8iLCJsc2QiOiJodHRwczovL3d3dy5nb29nbGUuY29tLmhrLyIsIm5jaWQiOiJuby1uY2lkIn0=' -O nccl_2.28.9-1%2Bcuda12.9_aarch64.txz
tar xvf nccl_2.28.9-1%2Bcuda12.9_aarch64.txz 

#mnubergemm binaries:
wget --user=junliz --ask-password https://urm.nvidia.com/artifactory/sw-nvlink-software-generic-local/LKG_RC/GB300NVL_72x1/ReleaseCandidate/1.0.00-build10/P4059/Software/mnubergemm/Prod/mnubergemm-aarch64-1.9.tgz
#wget --user=junliz --ask-password https://urm.nvidia.com/artifactory/sw-nvlink-software-generic-local/LKG_RC/GB200/2.0Build3/72x1/Tools/mnubergemm/1.6/mnubergemm-aarch64-1.6.tgz

## Method2:
# wget https://developer.download.nvidia.cn/compute/cuda/repos/ubuntu2204/sbsa/cuda-keyring_1.1-1_all.deb
# dpkg -i cuda-keyring_1.1-1_all.deb
# add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/sbsa/ /" -y
# #Install DCGM
# apt-get update
# apt-get install -y \
# datacenter-gpu-manager-4-core \
# datacenter-gpu-manager-4-proprietary \
# datacenter-gpu-manager-4-dev \
# datacenter-gpu-manager-exporter \
# datacenter-gpu-manager-4-multinode \
# datacenter-gpu-manager-4-cuda12 \
# datacenter-gpu-manager-4-proprietary-cuda12 \
# datacenter-gpu-manager-4-multinode-cuda12
## Then mnubergemm binary can be found at /usr/libexec/datacenter-gpu-manager-4/plugins/cuda12/mnubergemm