#! /bin/bash

#SBATCH -J ""nccl_tests        # job name
#SBATCH -A sw_aidot
#SBATCH --exclusive             # exclusive node access
#SBATCH --mem=0                 # all mem avail
#SBATCH --gpus-per-node=8
#SBATCH --output=%x_%j.out
#SBATCH --ntasks-per-node=8
#SBATCH --overcommit
#SBATCH --comment=sysctl-sys.kernel.numa_balancing=0,transparent_hugepage_defrag=never,transparent_hugepage=never

set -x
set -e -o pipefail

NODES=$SLURM_JOB_NUM_NODES
GPUS_PER_NODE=${SLURM_NTASKS_PER_NODE}

MAIN_LOG_DIR=oci_acceptance_ring_simple_192
WORKDIR=$PWD
LOGDIR=$WORKDIR/$MAIN_LOG_DIR
mkdir -p ${LOGDIR}

export NCCL_BUILD_PATH=/workspace/nccl/build
export LD_LIBRARY_PATH=$NCCL_BUILD_PATH/lib:$LD_LIBRARY_PATH
export NCCL_TEST_PATH=/workspace/nccl-tests/build

#PARAMS for sweep
NCCL_PARAMS=" env LD_LIBRARY_PATH=/workspace/nccl/build/lib env NCCL_BUFFSIZE= env NCCL_ALGO=Ring env NCCL_PROTO=Simple env NCCL_TESTS_SPLIT=${NCCL_TESTS_SPLIT} env NCCL_P2P_NET_CHUNKSIZE=131072 "
TESTS=(
    "alltoall_perf"
    "all_reduce_perf"
    "all_gather_perf"
    "reduce_scatter_perf"
)

TEST_PARAMS="-dfloat -b8 -e4G -f2 -g1"
TEST_PARAMS_A2A="-duint8 -b8 -e4G -f2 -g1"

srun -t5 -N 1 --ntasks-per-node 1 --mpi=pmix --container-image=${CONTAINER_NAME} ${NCCL_PARAMS} ls -lrt ${NCCL_TEST_PATH}
srun -t5 -N 1 --ntasks-per-node 1 --mpi=pmix --container-image=${CONTAINER_NAME} ${NCCL_PARAMS} ldd ${NCCL_TEST_PATH}/all_reduce_perf
srun -t5 -N 1 --ntasks-per-node 1 --mpi=pmix --container-image=${CONTAINER_NAME} ${NCCL_PARAMS} env | grep NCCL | tee ${LOGDIR}/env.txt

echo XXXX STARTING SWEEP on ${NODES} nodes
for TEST in ${TESTS[@]};
do
   echo XXXX RUNNING $TEST w/ $ALGO,$PROTO on ${NODES} nodes ${GPUS} GPUs
   LOGFILE=LOG_${TEST}_N${NODES}n${GPUS_PER_NODE}.txt
   if [[ "${TEST}" == "alltoall_perf" ]]; then
      NCCL_TEST_PARAMS=$TEST_PARAMS_A2A
   else
      NCCL_TEST_PARAMS=$TEST_PARAMS
   fi
   srun -N ${NODES} --ntasks-per-node ${GPUS_PER_NODE} --mpi=pmix --container-image=${CONTAINER_NAME} ${NCCL_PARAMS} ${NCCL_TEST_PATH}/${TEST} ${NCCL_TEST_PARAMS} | tee ${LOGDIR}/${LOGFILE}
done
