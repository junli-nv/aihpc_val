#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4

#timeout 100 bash /home/cmsupport/workspace/sysinfo.sh ${SLURM_JOB_NODELIST} 2>&1
module load slurm

cd ${SLURM_SUBMIT_DIR}

topdir=/home/cmsupport/workspace

source ${topdir}/hpcx-v2.22.1-gcc-doca_ofed-ubuntu24.04-cuda12-aarch64/hpcx-mt-init-ompi.sh
hpcx_load
source /etc/profile
module load shared
module load cuda12.8/toolkit/12.8.1

export LD_LIBRARY_PATH=${topdir}/nccl/bins:$LD_LIBRARY_PATH
export PATH=${topdir}/nccl/bins:$PATH
cd ${topdir}/nccl

hosts=($(scontrol show hostname $SLURM_JOB_NODELIST))

echo "INFO: cleaning work begin"
pdsh -R ssh -w ${SLURM_JOB_NODELIST} <<- 'EOF'|dshbak -c
ipmitool raw 0x3c 0x74 100 &>/dev/null || true
pkill -9 nccl || true
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
sysctl -w kernel.numa_balancing=0
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled
EOF
echo "INFO: cleaning work done"

##
unset tests
declare -A tests
tests[all_reduce_perf]="${topdir}/nccl/bins/all_reduce_perf -dfloat -b8 -e16G -f2 -g1"
tests[all_gather_perf]="${topdir}/nccl/bins/all_gather_perf -dfloat -b8 -e16G -f2 -g1"
tests[reduce_scatter_perf]="${topdir}/nccl/bins/reduce_scatter_perf -dfloat -b8 -e16G -f2 -g1"
tests[alltoall_perf]="${topdir}/nccl/bins/alltoall_perf -duint8 -b8 -e8G -f2 -g1"
#
HOSTS_LIST=$(for i in ${hosts[*]}; do echo ${i}:4; done|paste -s -d ',')
export NCCL_IB_TIMEOUT=25
export NCCL_IB_RETRY_CNT=8
for cmd in ${!tests[@]}; do
  sleep 15
  echo "INFO: ${cmd} BEGIN"
  set -e -o pipefail
  set -x
  ldd ${topdir}/nccl/bins/${cmd}
  mpirun --allow-run-as-root \
    --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
    --mca btl_tcp_if_include bond0 \
    --mca oob_tcp_if_include bond0 \
    --map-by ppr:2:socket:PE=36 \
    -x PATH=$PATH \
    -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
    -x OMPI_MCA_btl_openib_warn_default_gid_prefix=0 \
    -x OMPI_MCA_coll_hcoll_enable=0 \
    -x SLURM_CPU_BIND=none \
    -x OMPI_MCA_pml=ucx \
    -x UCX_TLS=rc_x,cuda \
    -x OMPI_MCA_btl=^openib,smcuda \
\
    -x NCCL_SOCKET_IFNAME=bond0 \
    -x UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1,mlx5_4:1,mlx5_5:1" \
    -x NCCL_IB_HCA="=mlx5_0,mlx5_1,mlx5_4,mlx5_5" \
\
    -x NCCL_DEBUG=WARN \
    -x NCCL_BUFFSIZE= \
    -x NCCL_ALGO=Ring \
    -x NCCL_PROTO=Simple \
    -x NCCL_TESTS_SPLIT=MOD72 \
    -x NCCL_P2P_NET_CHUNKSIZE=131072 \
\
    -H ${HOSTS_LIST} \
    -np $[4*${#hosts[*]}] \
    bash -c "ulimit -s 8192; ${tests[$cmd]}"
  exitcode=$?
  if [ $exitcode -ne 0 ]; then
    exit 1
  fi
  set +x 
  echo "INFO: ${cmd} DONE"
done

