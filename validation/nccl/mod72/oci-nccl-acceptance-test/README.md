# OCI NCCL Acceptance Test
## Basic Information
 - **Name and Description of the test**: The NCCL Acceptance Test is a network communication performance evaluation that assesses whether point-to-point and collective communication functions correctly across the full range of message sizes.
 - **Tool/Executable to be used for the test**: slurm (including pmix and pyxis plugins), NCCL 2.23.4, NCCL test 2.14.
   - NCCL Params: `NCCL_IB_HCA=^mlx5_4,mlx5_5`, `NCCL_ALGO=Ring`, `NCCL_PROTO=Simple`, `NCCL_P2P_NET_CHUNKSIZE=131072`
 - **How to interpret test results**: The script `acceptance_test.sh` will record the comparison between the measured and reference AUC for each function, indicating whether it has passed or failed the acceptance test.
 - **What action to take if a test fails**: The first step is to examine the `.png` file logged by the test to identify which functions and message sizes are underperforming. To investigate the root cause, enabling `NCCL_DEBUG=WARN` and reruning the relevant test will help.
 - **Expected log output format for the test**:
   - `oci_acceptance_ring_simple_192`: this includes the NCCL environment variables and the raw logs.
   - `*.png`: These visualizations illustrate how the measured NCCL performance compares to the reference data across various message sizes and functions.
   - Terminal Output: This contains the analyzed results, including the measured and reference AUC, as well as the pass/fail status of each test.
## Steps to run the test
1. Log into the cluster, clone this repo and install the requirements.
```console
$ ssh cw-dfw-cs-001-login-01.cw-dfw-cs-001.hpc.nvidia.com
$ git clone ssh://git@gitlab-master.nvidia.com:12051/yunn/oci-nccl-acceptance-test
$ pip install -r requirements.txt
```
2. To run the acceptance test, you need a container that includes NCCL 2.23.4 and the NCCL test 2.14.0. You have two options for obtaining the container.
 - Option A: You can reuse the existing sqsh container.
```console
$ aws s3 --endpoint-url https://pdx.s8k.io cp s3://oci-nccl-acceptance-test-bucket/nvidia_pytorch_24.10.sqsh .
```
 - Option B: You can rebuild the sqsh container. The following commands create `nvidia_pytorch_24.10.sqsh` for acceptance test in your current folder.
```console
$ srun --pty --container-image nvcr.io\#nvidia/pytorch:24.10-py3 --container-save=nvidia_pytorch_24.10.sqsh bash -i
$ git clone -b v2.22.3-1 https://github.com/NVIDIA/nccl.git
$ cd nccl
$ make -j src.build
$ cd ..
$ git clone -b v2.14.0 https://github.com/NVIDIA/nccl-tests.git
$ cd nccl-tests
$ make MPI=1 MPI_HOME=/usr/local/mpi -j 32
$ exit # srun
```
3. Now we launch the NCCL test through slurm.
```console
$ CONTAINER_NAME=nvidia_pytorch_24.10.sqsh NCCL_TESTS_SPLIT=MOD8 sbatch -N 192 acceptance_nccl_tests_ring_simple.sh
```
Note that `NCCL_TESTS_SPLIT` depends on your NVL domain. If you use NVL8 for H100, please specify `NCCL_TESTS_SPLIT=MOD8`; if you use NVL72 for GB200, please specify `NCCL_TESTS_SPLIT=MOD72` and so on.

4. Check the NCCL environment variables before we move on.
```console
$ cat oci_acceptance_ring_simple_192/env.txt
NCCL_BUILD_PATH=/workspace/nccl/build
NCCL_TEST_PATH=/workspace/nccl-tests/build
NCCL_TESTS_SPLIT=MOD8
NCCL_VERSION=2.22.3
NCCL_DEBUG=WARN
NCCL_IB_HCA=^mlx5_4,mlx5_5
NCCL_IB_TIMEOUT=20
NCCL_IGNORE_CPU_AFFINITY=0
NCCL_BUFFSIZE=
NCCL_ALGO=Ring
NCCL_PROTO=Simple
NCCL_P2P_NET_CHUNKSIZE=131072
```
The important environment variables are `NCCL_VERSION`, `NCCL_IB_HCA`, `NCCL_ALGO`, `NCCL_PROTO`, `NCCL_P2P_NET_CHUNKSIZE`. If there is any difference, you should fix `NCCL_PARAMS` in `acceptance_nccl_tests_ring_simple.sh` and rerun step 3.

5. After Slurm jobs are finished, we run the acceptance test.
```console
$ sh acceptence_test.sh
```
If you want to run the acceptance for smaller size, you can modify the `acceptence_test.sh` to take different parameters
```
python analyze_results.py -m data_full.pkl --network ib --num_nvl_domains <num_nvl_domains> --maxbw_per_gpu 50000.0 --threshold 0.95
```

## Interpret Acceptance Results
The acceptance will log whether each op pass or fails as follows. You can also check the plots `alltoall.png`, `all_reduce.png`, `all_gather.png`, `reduce_scatter.png` on if the S-curves are well behaved.
```
Verifying NCCL acceptance for alltoall
Measured AUC: 925.66 MB^2/s vs Reference AUC: 789.08 MB^2/s
The AUC difference 1.17 is higher than the acceptance threshold 0.95. Accpetance has passed for alltoall.

Verifying NCCL acceptance for all_reduce
Measured AUC: 1694.06 MB^2/s vs Reference AUC: 1675.62 MB^2/s
The AUC difference 1.01 is higher than the acceptance threshold 0.95. Accpetance has passed for all_reduce.

Verifying NCCL acceptance for all_gather
Measured AUC: 1562.01 MB^2/s vs Reference AUC: 1669.46 MB^2/s
The AUC difference 0.94 is lower than the acceptance threshold 0.95. Accpetance has failed for all_gather.
Please check the plot all_gather.png

Verifying NCCL acceptance for reduce_scatter
Measured AUC: 1637.52 MB^2/s vs Reference AUC: 1672.53 MB^2/s
The AUC difference 0.98 is higher than the acceptance threshold 0.95. Accpetance has passed for reduce_scatter.

Unfortunately, the NCCL acceptance test has failed.
```
