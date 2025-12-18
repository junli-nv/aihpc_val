#!/bin/bash

# cmsh -c 'rack list'
rack=${1:-GB200-Rack1}

ct_ips=(
$(cmsh -c "device list -r ${rack}"|grep PhysicalNode|awk '{print $5}')
)
#echo ${ct_ips[@]}
nvsw_ips=(
$(cmsh -c "device list -r ${rack}"|grep Switch|awk '{print $4}')
)
#echo ${nvsw_ips[@]}

## ComputeTrays
i=0; for c in ${ct_ips[@]}; do
  export COMPUTE_NODE_${i}_IP=${c}
  i=$[i+1]
done
## Switches
i=0; for s in ${nvsw_ips[@]}; do
  export SWITCH_NODE_${i}_IP=${s}
  i=$[i+1]
done
export NMX_C_IP=${SWITCH_NODE_0_IP}

export COMPUTE_NODE_USER="root"
export COMPUTE_NODE_PASSWD="Nvidia@123"
export SWITCH_NODE_USER="admin"
export SWITCH_NODE_PASSWD="Nvidia@123"
export INTER_SWITCH_NODE_USER="root_inter_switch"
export INTER_SWITCH_NODE_PASSWD="root_inter_switch"
export BMC_USER="root"
export BMC_PASSWD="0penBmc"

cat spec_gb200_nvl_72_2_4_compute_nodes_nvlgpustress_partner_mfg.json \
 | jq ".global_args.cluster_cfg.cluster_node_logins.compute_node.user=\"${COMPUTE_NODE_USER}\"" \
 | jq ".global_args.cluster_cfg.cluster_node_logins.compute_node.passwd=\"${COMPUTE_NODE_PASSWD}\"" \
 | jq ".global_args.cluster_cfg.cluster_node_logins.switch_node.user=\"${SWITCH_NODE_USER}\"" \
 | jq ".global_args.cluster_cfg.cluster_node_logins.switch_node.passwd=\"${SWITCH_NODE_PASSWD}\"" \
 | jq ".global_args.cluster_cfg.cluster_node_logins.inter_switch_node.user=\"${INTER_SWITCH_NODE_USER}\"" \
 | jq ".global_args.cluster_cfg.cluster_node_logins.inter_switch_node.passwd=\"${INTER_SWITCH_NODE_PASSWD}\"" \
 | jq ".global_args.bmc_redfish_credentials.username=\"${BMC_USER}\"" \
 | jq ".global_args.bmc_redfish_credentials.password=\"${BMC_PASSWD}\"" \
 | jq ".global_args.bmc_ssh_credentials.username=\"${BMC_USER}\"" \
 | jq ".global_args.bmc_ssh_credentials.password=\"${BMC_PASSWD}\"" \
 | jq ".actions[1].args.enable_prometheus=true" \
\
 | sed \
  -e "s#10.114.248.6\"#${COMPUTE_NODE_0_IP}\"#g" \
  -e "s#10.114.248.7\"#${COMPUTE_NODE_1_IP}\"#g" \
  -e "s#10.114.248.8\"#${COMPUTE_NODE_2_IP}\"#g" \
  -e "s#10.114.248.9\"#${COMPUTE_NODE_3_IP}\"#g" \
  -e "s#10.114.248.10\"#${COMPUTE_NODE_4_IP}\"#g" \
  -e "s#10.114.248.11\"#${COMPUTE_NODE_5_IP}\"#g" \
  -e "s#10.114.248.12\"#${COMPUTE_NODE_6_IP}\"#g" \
  -e "s#10.114.248.13\"#${COMPUTE_NODE_7_IP}\"#g" \
  -e "s#10.114.248.14\"#${COMPUTE_NODE_8_IP}\"#g" \
  -e "s#10.114.248.15\"#${COMPUTE_NODE_9_IP}\"#g" \
  -e "s#10.114.248.16\"#${COMPUTE_NODE_10_IP}\"#g" \
  -e "s#10.114.248.17\"#${COMPUTE_NODE_11_IP}\"#g" \
  -e "s#10.114.248.18\"#${COMPUTE_NODE_12_IP}\"#g" \
  -e "s#10.114.248.19\"#${COMPUTE_NODE_13_IP}\"#g" \
  -e "s#10.114.248.20\"#${COMPUTE_NODE_14_IP}\"#g" \
  -e "s#10.114.248.21\"#${COMPUTE_NODE_15_IP}\"#g" \
  -e "s#10.114.248.22\"#${COMPUTE_NODE_16_IP}\"#g" \
  -e "s#10.114.248.23\"#${COMPUTE_NODE_17_IP}\"#g" \
  -e "s#10.114.248.101\"#${SWITCH_NODE_0_IP}\"#g" \
  -e "s#10.114.248.102\"#${SWITCH_NODE_1_IP}\"#g" \
  -e "s#10.114.248.103\"#${SWITCH_NODE_2_IP}\"#g" \
  -e "s#10.114.248.104\"#${SWITCH_NODE_3_IP}\"#g" \
  -e "s#10.114.248.105\"#${SWITCH_NODE_4_IP}\"#g" \
  -e "s#10.114.248.106\"#${SWITCH_NODE_5_IP}\"#g" \
  -e "s#10.114.248.107\"#${SWITCH_NODE_6_IP}\"#g" \
  -e "s#10.114.248.108\"#${SWITCH_NODE_7_IP}\"#g" \
  -e "s#10.114.248.109\"#${SWITCH_NODE_8_IP}\"#g" \
  -e "s#10.115.17.102:9352#${NMX_C_IP}:9352#g" 
