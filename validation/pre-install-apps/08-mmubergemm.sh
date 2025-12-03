#!/bin/bash
topdir=/home/cmsupport/workspace/
cd ${topdir}

##NCCL: https://developer.nvidia.com/nccl/nccl-download
wget -c 'https://developer.download.nvidia.com/compute/machine-learning/nccl/secure/2.28.9/agnostic/aarch64sbsa/nccl_2.28.9-1%2Bcuda12.9_aarch64.txz?__token__=exp=1764753523~hmac=5480d4624e9aa336788fe4b8a32a5048c1ed6e20a418225bdae41e2ab74fdc8d&t=eyJscyI6ImdzZW8iLCJsc2QiOiJodHRwczovL3d3dy5nb29nbGUuY29tLmhrLyIsIm5jaWQiOiJuby1uY2lkIn0=' -O nccl_2.28.9-1%2Bcuda12.9_aarch64.txz
tar xvf nccl_2.28.9-1%2Bcuda12.9_aarch64.txz 

#mnubergemm binaries:
wget --user=junliz --ask-password https://urm.nvidia.com/artifactory/sw-nvlink-software-generic-local/LKG_RC/GB300NVL_72x1/ReleaseCandidate/1.0.00-build10/P4059/Software/mnubergemm/Prod/mnubergemm-aarch64-1.9.tgz
#wget --user=junliz --ask-password https://urm.nvidia.com/artifactory/sw-nvlink-software-generic-local/LKG_RC/GB200/2.0Build3/72x1/Tools/mnubergemm/1.6/mnubergemm-aarch64-1.6.tgz
