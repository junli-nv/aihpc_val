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

## Method2: https://confluence.nvidia.com/display/STS/OAIC+Health+Check+Project?preview=%2F4505748450%2F4537716697%2FOAIC-HealthCheck-20251125.pdf
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
#
## Introduction
# DCGM's multi-node diagnostic is meant to provide a multi-node diagnostic that can be used in production by customers.
## SetupDCGM
# Multi-node Diagnostics depend on OpenMPI. As such, OpenMPI will need to be present on the system, and users who will run the diagnostic must be configured to run OpenMPI work on the nodes that are targeted for the diagnostic.
## Usage
# Required Arguments
# --hostList <hostList>
## Optional Arguments
# --hostEngineAddress <hostName> # Specifies the host this dcgmi command should connect to. Defaults to localhost.
# -p /--parameters <parameterList># Specifies parameters to be passed through to MNubergemm. Follows the same format as dcgmi diag parameters. Defaults to an empty string
# -v /--verbose # turns on verbose output. Defaults to false (verbose mode off).
# -d /--debugLevel <debug Level> # Specifies the debug level to use for logging. Defaults to DEBUG
# --debugLogFile <path to debug log> # Specifies the location for the log file. Defaults to "./dcgm_mndiag_debug.log”
## Sample Commands
# dcgmi mndiag --hostList "node1;node2;node3" # run on nodes 1, 2 and 3
# dcgmi mndiag --hostList "node1:5554=0,node2=0,node3=0" # run on just GPU 0 for nodes 1, 2, and 3, and connect to node1 on port 5554 instead of the default.
# dcgmi mndiag --hostList "node1;node2,node3" -v -d VERBOSE --debugLogFile /tmp/mndiag.log # Run on nodes 1, 2, and 3 in verbose mode with VERBOSE logging logged to /tmp/mndiag.log
