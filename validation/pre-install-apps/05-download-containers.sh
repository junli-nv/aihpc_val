#!/bin/bash

## Download aarch64 images on X86 BCM head node

topdir=/home/cmsupport/workspace
mkdir -p ${topdir}
cd ${topdir}

mkdir -p $HOME/.config/enroot/
cat > $HOME/.config/enroot/.credentials <<- 'EOF'
machine nvcr.io login $oauthtoken password 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
machine authn.nvidia.com login $oauthtoken password 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
EOF
chmod 0600 $HOME/.config/enroot/.credentials

## HPC benchmark Image
enroot import \
 --arch aarch64 \
 --output ${topdir}/hpc-benchmarks-25.04.sqsh \
 'docker://nvcr.io/nvidia/hpc-benchmarks:25.04'

## Nemo Image
enroot import \
 --arch aarch64 \
 --output ${topdir}/nemo-25.04.rc2.sqsh \
 'docker://nvcr.io/nvidian/nemo:25.04.rc2'

rm -rf $HOME/.config/enroot
rm -rf $HOME/.cache/enroot
