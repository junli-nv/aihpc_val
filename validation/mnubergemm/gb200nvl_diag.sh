#!/bin/bash
#https://apps.nvidia.com/pid/contentlibraries/detail?id=1129549

function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

###############################
# CONFIGURATION FOR GB200 NVL #
###############################
MM_SMS=112
NET_SMS=32
CE_SMS=8
MM_SMS_NO_NET=144
NET_SMS_ONLY_NET=152
PPR=4   #  2           4           2                   4
GPUS=72 # 36 (a-36x1) 36 (b-36x1) 72 (a-72x1 or 36x2) 72 (b-72x1 or 36x2)
HOSTFILE="/etc/nvidia-imex/nodes_config.cfg"
TIME_PER_TEST=3600
MAX_WORKLOAD=65536
WORKLOAD_GNC="GNC"
WORKLOAD_GC="GC"
WORKLOAD_N="N"

###############
# ALG 0 picks #
###############
SGEMM_ALGO=" --MM_type S_S_SSS   --MM_force_cublas_algo TAAAABQAAAADAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAKux4tcBAAAAAAAAAAAAAAAAAEQAAAAAAAAAAAAAAA== "
HMMA_ALGO="  --MM_type H_H_HSH   --MM_force_cublas_algo RwAAABcAAAAjAAAAAQAAAAAAAAAAAAAAAAAAAAAABgAAANyq4tcBAAIAAAACAAAAAAAAAEQAAAAAAAAAAAAAAA== "
TF32_ALGO="  --MM_type SX_SX_SSS --MM_force_cublas_algo SQAAABcAAAAiAAAAAQAAAAAAAAAAAAAAAAAAAAAACgAAAKux4tcBAAAAAAAAAAAAAAAAAE0AAAAAAAAAAAAAAA== "
QMMA_ALGO="  --MM_type Q_Q_TST   --MM_M_per_sm 1024   --MM_force_cublas_algo RwAAABcAAAAkAAAAAQAAAAAAAAAAAAAAAAAAAAAADQAAAKux4tcBABwAAAAcAAAADgAOAEQAAAAAAAAAAAAAAA== "
IMMA_ALGO="  --MM_type B_B_III   --MM_M_per_sm 1024   --MM_force_cublas_algo RwAAABQAAAAkAAAAAQAAAAAAAAAAAAAAAAAAAAAABgABAAoA4tcBAAMAAAADAAAACgAKAEgAAAAKAAAAAAAAAA== "
OMMA_ALGO="  --MM_type O_O_HSH   --MM_M_per_sm 1024   --MM_force_cublas_algo RwAAABQAAAAlAAAAAQAAAAAAAAAAAAAAAAAAAAAABgABAAIA4tcBACEAAAAhAAAAAgACAEQAAAAAAAAAAAAAAA== "

###################
# max power picks #
###################
HMMA_ALT_ALGO="     --MM_type H_H_HSH   --MM_force_cublas_algo RwAAABcAAAAjAAAAAQAAAAAAAAAAAAAAAAAAAAAABgAAAAAA4tcBAAIAAAACAAAAAgACAEQAAAAAAAAAAAAAAA== "
FP32_AS_BF16_ALGO=" --MM_type ST_ST_SSS --MM_force_cublas_algo SQAAABQAAAAiAAAAAQAAAAAAAAAAAAAAAAAAAAAACQAAAAAA4tcBAAAAAAAAAAAAAAAAAEsAAAAAAAAAAAAAAA== "

########################
# MOVE ARGS INTO PLACE #
########################
MPI_ARGS="-x LD_LIBRARY_PATH=. -map-by ppr:${PPR}:node -n ${GPUS} --hostfile ${HOSTFILE} -mca btl_tcp_if_include enP5p9s0 -mca btl tcp,self"
STD_GNC="--time_to_run ${TIME_PER_TEST} --dynamic_adj --MM_max_workload ${MAX_WORKLOAD} --max_workload ${MAX_WORKLOAD} --MM_sm_count ${MM_SMS} --NET_sm_count ${NET_SMS} --workload ${WORKLOAD_GNC} --CE_type H --MM_N 0"
STD_GC=" --time_to_run ${TIME_PER_TEST} --dynamic_adj --MM_max_workload ${MAX_WORKLOAD} --max_workload ${MAX_WORKLOAD} --MM_sm_count ${MM_SMS_NO_NET} --workload ${WORKLOAD_GC} --CE_type H --MM_N 0 "
STD_N="  --time_to_run ${TIME_PER_TEST} --dynamic_adj --MM_max_workload ${MAX_WORKLOAD} --max_workload ${MAX_WORKLOAD} --NET_sm_count ${NET_SMS_ONLY_NET} --workload ${WORKLOAD_N}"

jump=${1:-"START"}
jumpto $jump


START:


################
# CONNECTIVITY #
################
connectivity0:
NET_ARGS="--NET_link_order pair --NET_size 2048000000 "
TESTNAME="CONNECTIVITY0"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_N} ${TIME_TO_RUN} ${NET_ARGS} --freq 1 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

connectivity1:
NET_ARGS="--NET_link_order snake --NET_size 2048000000 "
TESTNAME="CONNECTIVITY1"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_N} ${TIME_TO_RUN} ${NET_ARGS} --freq 1 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


connectivity2:
NET_ARGS="--NET_link_order scatter_sum --NET_size 2048000000 "
TESTNAME="CONNECTIVITY2"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_N} ${TIME_TO_RUN} ${NET_ARGS} --freq 1 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##################
# SGEMM DATATYPE #
##################
SGEMM:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="SGEMM"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${SGEMM_ALGO} --freq 10 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


##########################
# SGEMM DATATYPE PULSING #
##########################
SGEMM_PULSE:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 25600000 "
CE_ARGS=" --CE_size 12800000 "
TESTNAME="SGEMM PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${SGEMM_ALGO} --freq 25 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##################
# HMMA DATATYPE #
##################
HMMA:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="HMMA"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALGO} --freq 10 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


##########################
# HMMA DATATYPE PULSING #
##########################
HMMA_PULSE:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 25600000 "
CE_ARGS=" --CE_size 12800000 "
TESTNAME="HMMA PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALGO} --freq 25 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##################
# TF32 DATATYPE #
##################
TF32:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="TF32"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${TF32_ALGO} --freq 10 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


##########################
# TF32 DATATYPE PULSING #
##########################
TF32_PULSE:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 25600000 "
CE_ARGS=" --CE_size 12800000 "
TESTNAME="TF32 PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${TF32_ALGO} --freq 25 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##################
# QMMA DATATYPE #
##################
QMMA:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="QMMA"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${QMMA_ALGO} --freq 10 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##########################
# QMMA DATATYPE PULSING #
##########################
QMMA_PULSE:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 25600000 "
CE_ARGS=" --CE_size 12800000 "
TESTNAME="QMMA PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${QMMA_ALGO} --freq 25 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##################
# IMMA DATATYPE #
##################
IMMA:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="IMMA"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${IMMA_ALGO} --freq 10 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##########################
# IMMA DATATYPE PULSING #
##########################
IMMA_PULSE:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 25600000 "
CE_ARGS=" --CE_size 12800000 "
TESTNAME="IMMA PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${IMMA_ALGO} --freq 25 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi



##################
# OMMA DATATYPE #
##################
OMMA:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="OMMA"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${OMMA_ALGO} --freq 10 --duty 1.0"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

##########################
# OMMA DATATYPE PULSING #
##########################
OMMA_PULSE:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 25600000 "
CE_ARGS=" --CE_size 12800000 "
TESTNAME="OMMA PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${OMMA_ALGO} --freq 25 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


###########################################################
# Pulse Sweep with max pwr hmma kernel and nvlink traffic #         
###########################################################
PULSE0:

1hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 2048000000 "
CE_ARGS=" --CE_size 1024000000 "
TESTNAME="1hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --MM_M_per_sm 1024 --freq 1 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

2hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 1024000000 "
CE_ARGS=" --CE_size 512000000 "
TESTNAME="2hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --MM_M_per_sm 512 --freq 2 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

5hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 512000000 "
CE_ARGS=" --CE_size 256000000 "
TESTNAME="5hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 5 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


10hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 256000000 "
CE_ARGS=" --CE_size 128000000 "
TESTNAME="10hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 10 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


20hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 128000000 "
CE_ARGS=" --CE_size 64000000 "
TESTNAME="20hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 20 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


50hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 64000000 "
CE_ARGS=" --CE_size 32000000 "
TESTNAME="50hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 50 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

100hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 32000000 "
CE_ARGS=" --CE_size 16000000 "
TESTNAME="100hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 100 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


200hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 16000000 "
CE_ARGS=" --CE_size 8000000 "
TESTNAME="200hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 200 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


500hz_NET:
NET_ARGS=" --NET_link_order scatter_sum --NET_size 8000000 "
CE_ARGS=" --CE_size 4000000 "
TESTNAME="500hz PULSE HMMA with Networking"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GNC} ${TIME_TO_RUN} ${NET_ARGS} ${CE_ARGS} ${HMMA_ALT_ALGO} --freq 500 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


##################################################
# Pulse Sweep with max pwr FAST FP32/BF16 kernel #
##################################################
PULSE1:

1hz:
CE_ARGS=" --CE_size 1024000000 "
TESTNAME="1hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 1 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

2hz:
CE_ARGS=" --CE_size 640000000 "
TESTNAME="2hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 2 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

5hz:
CE_ARGS=" --CE_size 320000000 "
TESTNAME="5hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 5 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


10hz:
CE_ARGS=" --CE_size 160000000 "
TESTNAME="10hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 10 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

20hz:
CE_ARGS=" --CE_size 80000000 "
TESTNAME="20hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 20 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

50hz:
CE_ARGS=" --CE_size 40000000 "
TESTNAME="50hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 50 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


100hz:
CE_ARGS=" --CE_size 20000000 "
TESTNAME="100hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 100 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

200hz:
CE_ARGS=" --CE_size 10000000 "
TESTNAME="200hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 200 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

500hz:
CE_ARGS=" --CE_size 4000000 "
TESTNAME="500hz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 500 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

1khz:
CE_ARGS=" --CE_size 2000000 "
TESTNAME="1khz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 1000 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

2khz:
CE_ARGS=" --CE_size 1000000 "
TESTNAME="2khz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 2000 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

5khz:
CE_ARGS=" --CE_size 400000 "
TESTNAME="5khz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 5000 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi

10khz:
CE_ARGS=" --CE_size 200000 "
TESTNAME="10khz PULSE"
CMD="mpirun ${MPI_ARGS} ./mnubergemm ${STD_GC} ${TIME_TO_RUN} ${CE_ARGS} ${FP32_AS_BF16_ALGO} --freq 10000 --duty 0.5"
echo "[MNMM] ${TESTNAME} STARTING"
echo ${CMD}
${CMD}
if test $? -eq 0; then
    echo "[MNMM] ${TESTNAME} PASSED"
else
    echo "[MNMM] ${TESTNAME} FAILED"
    exit 1
fi


exit


