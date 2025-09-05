#!/bin/bash
#

## Start a interactive job
srun -N 1 --reservation=junli_val \
  --container-writable \
  --container-image /home/cmsupport/workspace/nemo-25.04.rc2.sqsh \
  --container-save /home/cmsupport/workspace/nemo-25.04.rc2.m2.sqsh \
  --container-mounts /dev/:/dev,$PWD:$PWD \
  --container-workdir /opt/NeMo  \
  --wait=120 --kill-on-bad-exit=0 --mpi=pmix \
  --pty bash

## Compile NCCL in the container
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
git checkout v2.28.3-1
make -j src.build
mv /usr/lib/aarch64-linux-gnu/libnccl.so.2.27.7 /usr/lib/aarch64-linux-gnu/libnccl.so.2.27.7
cp build/lib/libnccl.so.2.28.3 /usr/lib/aarch64-linux-gnu/libnccl.so.2.28.3
ln -sf libnccl.so.2.28.3 libnccl.so.2
ln -sf libnccl.so.2 libnccl.so
cd -
cp ./build/include/nccl.h /usr/include/nccl.h
cp ./build/bin/ncclras /usr/bin/ncclras
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
make -j MPI=1 NAME_SUFFIX=_mpi MPI_HOME=/usr/local/mpi NCCL_HOME=$PWD/../build
cp build/*_mpi /usr/local/bin/

## Exit to save the container
exit

## Sign the new built container
md5sum /home/cmsupport/workspace/nemo-25.04.rc2.m2.sqsh > /home/cmsupport/workspace/nemo-25.04.rc2.m2.sqsh.md5sum


