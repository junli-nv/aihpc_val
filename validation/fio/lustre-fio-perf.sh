#!/bin/bash
sshpass -p DDNSolutions4U \
scp root@10.0.0.129:/scratch/EXAScaler-6.3.3/client/exa_client_perf_scripts-1.1.9.tar.gz /home/cmsupport/ddn/
cd /home/cmsupport/ddn/
tar -xzvf exa_client_perf_scripts-1.1.9.tar.gz
cd exa_client_perf_scripts-1.1.9/
./exa_client_performance_validation.sh --help

hosts=($(echo 10.0.0.{1..24}))
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<< 'lctl set_param osc.*.checksums=0'

mkdir -p /scratch/test
rm -rf /scratch/test/*
./exa_client_performance_validation.sh --offline --verbose \
  --disable-copy-id --disable-docker --disable-src --disable-exa-drop --disable-mount-check \
  -m /scratch/test \
  --client "${hosts[*]}" \
  -p 96
rm -rf /scratch/test/*

## 16 clients
#------------------------------------------------------------------
#|   v1.1.9   |   Read BW  |  Write BW  | Read IOPS  | Write IOPS |
#|Performance |        346G|        330G|       4858k|       1617k|
#|Total time  |         42s|         42s|         42s|         42s|
#------------------------------------------------------------------
## 24 clients
#------------------------------------------------------------------
#|   v1.1.9   |   Read BW  |  Write BW  | Read IOPS  | Write IOPS |
#|Performance |        355G|        330G|       7241k|       1787k|
#|Total time  |         43s|         43s|         42s|         42s|
#------------------------------------------------------------------
## 24 clients, after PFC/CC applied
#------------------------------------------------------------------
#|   v1.1.9   |   Read BW  |  Write BW  | Read IOPS  | Write IOPS |
#|Performance |        369G|        327G|       7173k|       1756k|
#|Total time  |         41s|         44s|         42s|         41s|
#------------------------------------------------------------------
## 24 clients, after lnet_peer_discovery_disabled=1 be removed from client side and multi rail route priorities tuning on server side
#------------------------------------------------------------------
#|   v1.1.9   |   Read BW  |  Write BW  | Read IOPS  | Write IOPS |
#|Performance |        443G|        366G|       7299k|       1737k|
#|Total time  |         42s|         42s|         42s|         42s|
#------------------------------------------------------------------
