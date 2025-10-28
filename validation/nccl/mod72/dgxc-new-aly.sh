#!/bin/bash

## Updated script for ploting: https://gitlab-master.nvidia.com/aidot/acceptance-test/-/tree/main?ref_type=heads
git clone ssh://git@gitlab-master.nvidia.com:12051/aidot/acceptance-test.git
cd acceptance-test
git checkout c2bf30cf497e14932b6bb484ab196743a891d788
cd network
python3 -m venv venv
source venv/bin/activate
pip install pandas matplotlib numpy scikit-learn scipy

## 27 Racks NCCL Sweep
logf=../../rawlogs/root-MOD72-27Rack-a02_a08_a10_a12_a14_a16_b03_b05_b07_b09_b11_b13_b15_b17_g02_g04_g06_g08_g10_g12_g14_g16_h03_h05_h07_h09_h17-486N-18698.txt
logd=nccl_sweep_2.27.7_N27
mkdir -p $logd
for cmd in reduce_scatter_perf all_reduce_perf all_gather_perf alltoall_perf; do
 cat ${logf}|awk "/INFO: ${cmd} BEGIN/,/INFO: ${cmd} DONE/{print \$0}" | awk '/# Collective test startin/,/# Collective test concluded/{print $0}'|grep -v NCCL \
     &> ${logd}/LOG_${cmd}_N$(echo ${logf}|awk -F'-' '{print $(NF-1)}'|tr -d 'N')n4.txt
done
(
python analysis.py --op all_gather     --nvl_domains 27 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N27/LOG_all_gather_perf_N486n4.txt
python analysis.py --op all_reduce     --nvl_domains 27 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N27/LOG_all_reduce_perf_N486n4.txt
python analysis.py --op all_to_all     --nvl_domains 27 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N27/LOG_alltoall_perf_N486n4.txt
python analysis.py --op reduce_scatter --nvl_domains 27 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N27/LOG_reduce_scatter_perf_N486n4.txt
) 2>&1 | tee output.txt
mv *.png output.txt nccl_sweep_2.27.7_N27

## 31 Racks NCCL Sweep
logf=../../rawlogs/root-MOD64-31Rack-a02_a04_a06_a08_a10_a12_a14_a16_b03_b05_b07_b09_b11_b13_b15_b17_g02_g04_g06_g08_g10_g12_g14_g16_h03_h05_h07_h09_h11_h13_h17-496N-18590.txt
logd=nccl_sweep_2.27.7_N31
mkdir -p $logd
for cmd in reduce_scatter_perf all_reduce_perf all_gather_perf alltoall_perf; do
 cat ${logf}|awk "/INFO: ${cmd} BEGIN/,/INFO: ${cmd} DONE/{print \$0}" | awk '/# Collective test startin/,/# Collective test concluded/{print $0}'|grep -v NCCL \
     &> ${logd}/LOG_${cmd}_N$(echo ${logf}|awk -F'-' '{print $(NF-1)}'|tr -d 'N')n4.txt
done
(
python analysis.py --op all_gather     --nvl_domains 31 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N31/LOG_all_gather_perf_N496n4.txt
python analysis.py --op all_reduce     --nvl_domains 31 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N31/LOG_all_reduce_perf_N496n4.txt
python analysis.py --op all_to_all     --nvl_domains 31 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N31/LOG_alltoall_perf_N496n4.txt
python analysis.py --op reduce_scatter --nvl_domains 31 --max_bw_mbps 50000 --file nccl_sweep_2.27.7_N31/LOG_reduce_scatter_perf_N496n4.txt
) 2>&1 | tee output.txt
mv *.png output.txt nccl_sweep_2.27.7_N31
