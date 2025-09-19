#!/bin/bash

topdir=/home/cmsupport/workspace/nccl/run
cd ${topdir}

## 
git clone https://gitlab-master.nvidia.com/yunn/oci-nccl-acceptance-test

## 
apt install -y python3-venv
cd oci-nccl-acceptance-test
python -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt

