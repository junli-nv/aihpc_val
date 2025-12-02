#!/bin/bash
#
node_prefix="gb200"
sw_prefix="nvsw"
ps_prefix="ps"

cmsh -c 'device; foreach -t PhysicalNode ( get hostname; interfaces; list bmc)' \
  | grep -E "${node_prefix}-|bmc" | paste - - | awk '{print $1,$4}' | tee hosts.list

cmsh -c 'device; foreach -t Switch ( get hostname; interfaces; list bmc)' \
  | grep -E "${sw_prefix}-|bmc" | paste - - | awk '{print $1,$4}' | tee -a hosts.list

cmsh -c 'device; foreach -t PowerShelf ( get hostname; interfaces; list bmc)' \
  | grep -E "${ps_prefix}-|bmc" | paste - - | awk '{print $1,$4}' | tee -a hosts.list
