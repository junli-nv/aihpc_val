#!/bin/bash

set -x

nfs_share_dir=$PWD/tmp
mkdir -p ${nfs_share_dir}
cd ${nfs_share_dir}
ln -sf /raid/data/nemo-25.04.rc2.m2.sqsh nemo-25.04.rc2.sqsh
cp ../pretrain_nemotron4_340b.sh .

#GPUs=64
GPUs=$[560*4]
srun --reservation=junli_val -N 1 --gpus-per-node=1 --export=nfs_share_dir \
  --container-image=${nfs_share_dir}/nemo-25.04.rc2.sqsh \
  --container-mounts=${nfs_share_dir}:${nfs_share_dir} \
  --container-writable \
  env nfs_share_dir=${nfs_share_dir} \
  bash ${nfs_share_dir}/pretrain_nemotron4_340b.sh ${GPUs} 2>&1 \
  | tee ${nfs_share_dir}/log-${GPUs}.txt

