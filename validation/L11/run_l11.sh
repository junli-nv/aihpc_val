#!/bin/bash

## https://apps.nvidia.com/PID/ContentLibraries/Detail/1127062
cd /home/cmsupport/workspace/629-24972-4975-FLD-50898-rev23

# cmsh -c 'rack list'
rack=GB200-Rack2

BCM_HEADNODE_IP=10.135.8.2

pdsh -R ssh -w $(cmsh -c "device list -r ${rack}"|grep PhysicalNode|awk '{print $2}'|paste -sd, -) <<- EOF | dshbak -c
systemctl stop cmd munge slurmd nvidia-persistenced nvidia-dcgm nvidia-imex nvsm
modprobe -r nvidia_drm nvidia_uvm nvidia_modeset gdrdrv nvidia_cspmu nvidia_fs nv_peer_mem nv_peermem nvidia_peermem 
modprobe --remove --remove-dependencies -f nvidia
dmidecode | grep -e 699-2G548-1201-A00 -e 699-2G548-1201-A10 -e 699-2G548-1201-800 -e 699-2G548-0202-800 -e 699-2G548-0202-A00
EOF

bash gen-config.sh ${rack} > ${rack}.json
netstat -anp|grep 15650
netstat -anp|grep $(cat ${rack}.json|jq '.global_args.cluster_cfg.gdm_port')
pkill -9 python3

## If you want to run multiple racks concurrently:
# Use different run directories per rack (separate working dirs and logs)
# Ensure each rack uses a unique gdm_port to prevent collisions
## Important: bonded interfaces are not supported for the GDM implementation in Partner Diags
# This includes the node from which you’re launching the partner diags and the compute nodes.
# Partner diags GDM code will not work on bonded interfaces.
# Use a non-bonded interface/IP for --primary_diag_ip
# Reference: NVBug 5679837: https://nvbugspro.nvidia.com/bug/5679837

#  --loopback_ip=127.0.0.1 \
./partnerdiag --mfg --run_spec=${rack}.json \
  --primary_diag_ip=${BCM_HEADNODE_IP} \
  --topology=topo_72x1.json --test=NvlGpuStress --no_bmc 2>&1 | tee ${rack}-output.txt

grep 'Final Result:' partnerdiag.log
grep -e 'NvlGpuStress.*NVLink.*Error Threshold Exceeded' -e 'NETIR_LINK_EVT.*Fatal' run.log
