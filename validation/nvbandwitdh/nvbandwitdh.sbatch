#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4
#SBATCH --time=00:13:00
#SBATCH -N 1

cd ${SLURM_SUBMIT_DIR}
echo "NODELIST=$SLURM_JOB_NODELIST"
set -ex
topdir=/home/cmsupport/workspace
BIN1=${topdir}/nvbandwidth/nvbandwidth.SN
ldd ${BIN1}
CUDA_VISIBLE_DEVICES=0,1,2,3 \
${BIN1} -t device_to_device_memcpy_read_ce
set +ex
