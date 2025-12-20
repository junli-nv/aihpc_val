# MNUbergemm

A diagnostic tool for running synchronous pulsing workload across a cluster.

## Preparation

Follow http://nv/dcdiags steps 1 and 2 to get access to build releases.  The included resources in the 1.5 release will support Hopper, Blackwell and GB20x.

Ensure the cluster you will be testing on has a functioning fabric.  This can be accomplished with the nvidia.nvlink.nvidia.nvlink.gb200_status_health_check (https://gitlab-master.nvidia.com/nvlink/ansible/collections/nvidia.nvlink.git) script on gb200nvl.

## Running

MNubergemm commandlines can be divided into several sections.

`mpirun ${MPI_ARGS} ./mnubergemm ${STD_ARGS} ${MM_ARGS} ${CE_ARGS} ${NET_ARGS}`

Example :

`mpirun -x NCCL_MAX_CTAS=32 -x LD_LIBRARY_PATH=. -map-by ppr:4:node -n 72 --hostfile hostfile -mca btl_tcp_if_include enP5p9s0 -mca btl tcp,self -mca plm_rsh_agent "ssh -l nvidia" /home/nvidia/1.5/mnubergemm --dynamic_adj --MM_max_workload 65536 --max_workload 65536 --MM_N 0 --time_to_run 300 --workload GNC --freq 500 --duty 0.5 --MM_sm_count 112 --MM_type Q_R_SSS --NET_sm_count 32 --NET_link_order scatter_sum --NET_size 512000 --CE_type H --CE_size 256000`

### MPI_ARGS

Args controling OpenMPI.

Example :

`MPI_ARGS = "-x NCCL_MAX_CTAS=32 -x LD_LIBRARY_PATH=. -map-by ppr:4:node -n 72 --hostfile hostfile -mca btl_tcp_if_include enP5p9s0 -mca btl tcp,self -mca plm_rsh_agent \"ssh -l nvidia\" "`

|    ARG        |  Meaning    |
|---------------|-------------|
| -x ARG=VALUE  | These args pass in env vars to the appliation to run. Of particular note is LD_LIBRARY_PATH which ensures paired cublas and cusparse libraries are used. |
| -map-by ppr:4:node -n 72 --hostfile hostfile | These args describe the distrbution of work across the cluster. In this case, 72 processes are launched, 4 on each node listed in "hostfile".  Hostfile is expected to have 18 entries. |
| -mca btl_tcp_if_include enP5p9s0 -mca btl tcp,self | Describes the networking for OpenMPI communication |
| -mca plm_rsh_agent \"ssh -l nvidia\" " | Causes the "nvidia" user to be used |

### STD_ARGS

Standard global args passed into MNUBERGEMM.

`STD_ARGS = --dynamic_adj  --time_to_run 300 --workload GNC --freq 500 --duty 0.5`

|    ARG        |  Meaning    |
|---------------|-------------|
| --dynamic_adj |During runtime adjust workload to meet timing. |
| --time_to_run 300 |  Time in seconds to run. |
| --workload GNC | (see below) |
| --freq 500 --duty 0.5 | Frequency and Duty cycle to target. |

| --workload | Meaning |
|------------|---------|
| G | GEMM workload using cublas or cusparse.|
| N | NVLINK workload using NCCL. |
| C | Copy engine workload. |

### MM_ARGS

Args controlling Matrix Multiply workload.

Example:

`MM_ARGS = --MM_sm_count 112 --MM_type Q_R_SSS --MM_N 0`

|    ARG        |  Meaning    |
|---------------|-------------|
| --MM_sm_count 112 | SMs to assign to MM workload. |
| --MM_type Q_R_SSS | (see below) |
| --MM_M | M dimension of matrix; 0 for scaling based on SM count |
| --MM_N | N dimension of matrix; 0 for coarse grained auto tune |


| --MM_type A_B_CED | Meaning |
|-------------------|---------|
| A | datatype of A matrix |
| B | datatype of B matrix |
| C | datatype of C matrix |
| D | datatype of D matrix |
| E | compute type |

| Datatype | Meaning |
|----------|---------|
| D | FP64 |
| S | FP32 |
| H | FP16 |
| T | BF16 |
| Q | FP8_E4M3 |
| R | FP8_E5M2 |
| O | FP4 |
| I | INT32 |
| B | INT8 |
| SX | TF32 |
| SH | FP32 as FP16 |
| ST | FP32 as BF16 |

| Valid Configurations | Notes |
|----------------------|-------|
| H_H_HHH | |
| B_B_III | |
| B_B_BIB | |
| B_B_III_TN | |
| B_B_BIB_TN | |
| T_T_TST | |
| H_H_HSH | |
| B_B_SSS | |
| T_T_SSS | |
| H_H_SSS | |
| S_S_SSS | |
| SH_SH_SSS | |
| ST_ST_SSS | |
| SX_SX_SSS | |
| D_D_DDD | |
| Q_Q_TST | |
| Q_Q_HSH | |
| Q_Q_SSS | |
| Q_R_TST | |
| Q_R_HSH | |
| Q_R_SSS | |
| R_Q_TST | |
| R_Q_HSH | |
| R_Q_SSS | |
| O_O_HSH | |

### NET_ARGS

Args controlling NVLINK/NCCL workload.

Example :

`NET_ARGS = "--NET_sm_count 32 --NET_link_order scatter_sum --NET_size 512000"`

|    ARG        |  Meaning    |
|---------------|-------------|
| --NET_sm_count 32 | SMs to assign to NET workload. |
| --NET_link_order scatter_sum | (see below) |
| --NET_size 512000 | copy buffer size |

| --NET_link_order | Meaning |
|------------------|---------|
| scatter_sum | Nodes perform a collective "reduce-sum scatter" operation |
| pairs | Nodes pair up and Copy with each other |
| snake | Nodes form a ring and copy around the ring |

### CE_ARGS

Args controlling Copy Engine workload.

Example:

CE_ARGS = "--CE_type H --CE_size 256000"

|    ARG        |  Meaning    |
|---------------|-------------|
| --CE_type H   | (see below) |
| --CE_size 256000 | copy buffer size |

| --CE_type | Meaning |
|-----------|---------|
| H | Copies to/from host memory |

## Output