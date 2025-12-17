#!/bin/bash

## https://apps.nvidia.com/PID/ContentLibraries/Detail/1127062
cd /home/cmsupport/workspace/629-24972-4975-FLD-50898-rev23

cp spec_gb200_nvl_72_2_4_compute_nodes_nvlgpustress_partner_mfg.json config_r02.json
## Modify config_r02.json

export COMPUTE_NODE_USER="root"
export COMPUTE_NODE_PASSWD="B1td1erNv@2025"
export SWITCH_NODE_USER="admin"
export SWITCH_NODE_PASSWD="Aivres@111"
export INTER_SWITCH_NODE_USER="root_inter_switch"
export INTER_SWITCH_NODE_PASSWD="root_inter_switch"
export BMC_USER="root"
export BMC_PASSWD="0penBmc"

# cmsh -c 'rack list'
# cmsh -c 'device list -r GB200-Rack1'
## ComputeTrays
i=0; for c in 10.135.0.{1..18}; do
  export COMPUTE_NODE_${i}_IP=${c}
  i=$[i+1]
done
## Switches
i=0; for s in 10.135.32.{64..80}; do
  export SWITCH_NODE_${i}_IP=${s}
  i=$[i+1]
done

sed \
  -e "s#\(.*user.*\)nvidia\(.*,\):\1${COMPUTE_NODE_USER}\2#g" \
  -e "s#\(.*passwd.*\)nvidia\(.*,\):\1${COMPUTE_NODE_PASSWD}\2#g" \
  -e "s#\(.*user.*\)admin\(.*,\):\1${SWITCH_NODE_USER}\2#g" \
  -e "s#\(.*passwd.*\)nvidia\(.*,\):\1${SWITCH_NODE_PASSWD}\2#g" \
  -e "s#\(.*user.*\)root\(.*,\):\1${INTER_SWITCH_NODE_USER}\2#g" \
  -e "s#\(.*passwd.*\)root\(.*,\):\1${INTER_SWITCH_NODE_PASSWD}\2#g" \
  -e "s#\(.*username.*\)root\(.*,\):\1${BMC_USER}\2#g" \
  -e "s#\(.*password.*\)0penBmc\(.*,\):\1${BMC_PASSWD}\2#g" \
  -e "s#10.114.248.19#${COMPUTE_NODE_0_IP}#g" \
  -e "s#10.114.248.20#${COMPUTE_NODE_1_IP}#g" \
  -e "s#10.114.248.21#${COMPUTE_NODE_2_IP}#g" \
  -e "s#10.114.248.22#${COMPUTE_NODE_3_IP}#g" \
  -e "s#10.114.248.10#${COMPUTE_NODE_4_IP}#g" \
  -e "s#10.114.248.11#${COMPUTE_NODE_5_IP}#g" \
  -e "s#10.114.248.12#${COMPUTE_NODE_6_IP}#g" \
  -e "s#10.114.248.13#${COMPUTE_NODE_7_IP}#g" \
  -e "s#10.114.248.101#${SWITCH_NODE_0_IP}#g" \
  -e "s#10.114.248.102#${SWITCH_NODE_1_IP}#g" \
  -e "s#10.114.248.103#${SWITCH_NODE_2_IP}#g" \
  -e "s#10.114.248.104#${SWITCH_NODE_3_IP}#g" \
  -e "s#10.114.248.105#${SWITCH_NODE_4_IP}#g" \
  -e "s#10.114.248.106#${SWITCH_NODE_5_IP}#g" \
  -e "s#10.114.248.107#${SWITCH_NODE_6_IP}#g" \
  -e "s#10.114.248.108#${SWITCH_NODE_7_IP}#g" \
  -e "s#10.114.248.109#${SWITCH_NODE_8_IP}#g" \
  -e "s#10.114.248.14#${COMPUTE_NODE_8_IP}#g" \
  -e "s#10.114.248.15#${COMPUTE_NODE_9_IP}#g" \
  -e "s#10.114.248.16#${COMPUTE_NODE_10_IP}#g" \
  -e "s#10.114.248.17#${COMPUTE_NODE_11_IP}#g" \
  -e "s#10.114.248.18#${COMPUTE_NODE_12_IP}#g" \
  -e "s#10.114.248.19#${COMPUTE_NODE_13_IP}#g" \
  -e "s#10.114.248.20#${COMPUTE_NODE_14_IP}#g" \
  -e "s#10.114.248.21#${COMPUTE_NODE_15_IP}#g" \
  -e "s#10.114.248.22#${COMPUTE_NODE_16_IP}#g" \
  -e "s#10.114.248.23#${COMPUTE_NODE_17_IP}#g" \
  -e 's#"enable_prometheus": true#"enable_prometheus": false#' \
  spec_gb200_nvl_72_2_4_compute_nodes_nvlgpustress_partner_mfg.json > config.json

./partnerdiag --mfg --run_spec=config.json --primary_diag_ip=10.135.8.2 --loopback_ip=127.0.0.1 --topology=topo_72x1.json --test=NvlGpuStress --no_bmc

grep 'Final Result:' partnerdiag.log
grep -e 'NvlGpuStress.*NVLink.*Error Threshold Exceeded' -e 'NETIR_LINK_EVT.*Fatal' run.log
