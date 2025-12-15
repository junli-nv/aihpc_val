#!/bin/bash

# ## Install cuda toolkit
# #apt list|grep BCM|grep cuda
# apt install -y 'cuda12.8-sdk/BCM 11' 'cuda12.8-toolkit/BCM 11' 'cuda12.8-visual-tools/BCM 11'
# module load shared
# module avail
# module load cuda12.8/toolkit/12.8.1

cd /home/cmsupport/workspace

# https://developer.nvidia.com/cuda-toolkit-archive
## CUDA 12
# wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda_12.8.1_570.124.06_linux_sbsa.run
wget -c https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda_12.9.1_575.57.08_linux_sbsa.run
## CUDA 13
# wget -c https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux_sbsa.run

## Install cuda toolkits on a compute node
mkdir -p /home/cmsupport/workspace/cuda
bash cuda_12.9.1_575.57.08_linux_sbsa.run --silent --toolkit --no-opengl-libs --no-drm --installpath=/home/cmsupport/workspace/cuda12
# bash cuda_13.1.0_590.44.01_linux_sbsa.run --silent --toolkit --no-opengl-libs --no-drm --installpath=/home/cmsupport/workspace/cuda13
ln -sf /home/cmsupport/workspace/cuda12 /home/cmsupport/workspace/cuda

cat > /home/cmsupport/workspace/cuda/env.sh <<- 'EOF'
#!/bin/bash
export CUDA_HOME=/home/cmsupport/workspace/cuda
export PATH=${CUDA_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
EOF
chmod +x /home/cmsupport/workspace/cuda/env.sh
