#!/bin/bash
#

## Download nemo container
topdir=/home/cmsupport/workspace
mkdir -p ${topdir}
cd ${topdir}
mkdir -p $HOME/.config/enroot/
cat > $HOME/.config/enroot/.credentials <<- 'EOF'
machine nvcr.io login $oauthtoken password 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
machine authn.nvidia.com login $oauthtoken password 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
EOF
chmod 0600 $HOME/.config/enroot/.credentials
enroot import \
 --output ${topdir}/nemo-25.04.rc2.sqsh \
 'docker://nvcr.io/nvidian/nemo:25.04.rc2'
rm -rf $HOME/.config/enroot
rm -rf $HOME/.cache/enroot

## Update the container
srun -N 1 --reservation=junli_val \
  --container-writable \
  --container-image ${topdir}/nemo-25.04.rc2.sqsh \
  --container-save ${topdir}/nemo-25.04.rc2.m2.sqsh \
  --container-mounts /dev/:/dev,$PWD:$PWD \
  --container-workdir /opt/NeMo  \
  --wait=120 --kill-on-bad-exit=0 --mpi=pmix \
  --pty bash

## Compile NCCL in the container
git clone https://github.com/NVIDIA/nccl.git
cd nccl/
git checkout v2.28.3-1
make -j src.build
rm -f /usr/lib/aarch64-linux-gnu/libnccl*
cp build/lib/libnccl.so.2.28.3 /usr/lib/aarch64-linux-gnu/libnccl.so.2.28.3
cp build/lib/libnccl_static.a /usr/lib/aarch64-linux-gnu/libnccl_static.a
cd /usr/lib/aarch64-linux-gnu
ln -sf libnccl.so.2.28.3 libnccl.so.2
ln -sf libnccl.so.2 libnccl.so
ls -lh /usr/lib/aarch64-linux-gnu/libnccl*
cd -
cp ./build/include/nccl.h /usr/include/nccl.h
cp ./build/bin/ncclras /usr/bin/ncclras
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
make -j MPI=1 NAME_SUFFIX=_mpi MPI_HOME=/usr/local/mpi NCCL_HOME=$PWD/../build
rm -f /usr/local/bin/*_perf*
cp build/*_mpi /usr/local/bin/
ls -lh /usr/local/bin/*_perf*
rm -rf build/
rm -rf ../build/
history -c
## Exit to save the container
exit 0

## Sign the new built container
md5sum ${topdir}/nemo-25.04.rc2.m2.sqsh > ${topdir}/nemo-25.04.rc2.m2.sqsh.md5sum


