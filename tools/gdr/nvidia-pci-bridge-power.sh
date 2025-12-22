#!/bin/bash

# Set CPU frequency governor to performance
/usr/bin/cpupower frequency-set -g performance

# Keep this PCIe root port permanently active, don’t auto suspend it.
BRIDGE_BDF=( `lspci -D | grep "PCI bridge: " | awk '{print $1}'` )
BRIDGE_SEC_BDF=( `lspci -vv | grep -A 10 "PCI bridge: " | grep "Bus: " | awk '{print $3}' | sed 's/secondary=//' | sed 's/,//'` )
BRIDGE_SUB_BDF=( `lspci -vv | grep -A 10 "PCI bridge: " | grep "Bus: " | awk '{print $4}' | sed 's/subordinate=//' | sed 's/,//'` )
for GPU_BUS in `lspci | grep "3D controller: NVIDIA" | awk '{print $1}' | sed 's/.....$//'`; do
  for i in "${!BRIDGE_BDF[@]}"; do
    if [ $((16#${BRIDGE_SEC_BDF[i]})) -le $((16#$GPU_BUS)) ] && [ $((16#$GPU_BUS)) -le $((16#${BRIDGE_SUB_BDF[i]})) ]; then
      NEW_BDF=${BRIDGE_BDF[i]}
      filename=`echo "/sys/bus/pci/drivers/pcieport/BDF/power/control" | sed "s/BDF/$NEW_BDF/"`
      echo on > $filename
    fi
  done
done