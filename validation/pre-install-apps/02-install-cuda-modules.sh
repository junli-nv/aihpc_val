#!/bin/bash

# ## Install cuda toolkit
# #apt list|grep BCM|grep cuda
# apt install -y 'cuda12.8-sdk/BCM 11' 'cuda12.8-toolkit/BCM 11' 'cuda12.8-visual-tools/BCM 11'
# module load shared
# module avail
# module load cuda12.8/toolkit/12.8.1

cd /home/cmsupport/workspace

# https://developer.nvidia.com/cuda-toolkit-archive
wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda_12.8.1_570.124.06_linux_sbsa.run

cp -arv /cm/images/default-image-ubuntu2404-aarch64/ u2404-aarch64/
cp cuda_12.8.1_570.124.06_linux_sbsa.run u2404-aarch64/
chroot u2404-aarch64/
mkdir -p /home/cmsupport/workspace/cuda
bash cuda_12.8.1_570.124.06_linux_sbsa.run --silent --toolkit --no-opengl-libs --no-drm --installpath=/home/cmsupport/workspace/cuda
exit
mv u2404-aarch64/home/cmsupport/workspace/cuda .
rm -rf u2404-aarch64

cat > /home/cmsupport/workspace/cuda/env.sh <<- 'EOF'
#!/bin/bash
export CUDA_HOME=/home/cmsupport/workspace/cuda
export PATH=${CUDA_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
EOF
chmod +x /home/cmsupport/workspace/cuda/env.sh
