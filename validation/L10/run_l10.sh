#!/bin/bash

## https://apps.nvidia.com/pid/contentlibraries/detail?id=1122743
# Upload the package to the head node first if not already done
rsync --bwlimit=500 -P -e "ssh" \
  ./629-24975-0000-FLD-50896-rev13.tgz \
  root@192.168.0.124:/home/cmsupport/workspace/629-24975-0000-FLD-50896-rev13.tgz
# Then ssh to the head node and extract
cd /home/cmsupport/workspace/
mkdir -p $(hostname)
cd $(hostname)
tar xzvf ../629-24975-0000-FLD-50896-rev13.tgz
cd 629-24975-0000-FLD-50896-rev13

systemctl stop cmd.service munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service docker.service
modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia_cspmu gdrdrv nvidia

sed -e 's#"enable_prometheus": true#"enable_prometheus": false#g' spec_gb200_nvl_2_4_board_pc_nvlgpustress_partner_mfg.json > config.json
./partnerdiag --mfg --run_spec=config.json --run_on_error --no_bmc 2>&1 | tee $(hostname)-output.txt

grep 'Final Result:' dgx/latest_log/partnerdiag.log
grep -e 'NvlGpuStress' dgx/latest_log/run.log
grep -e 'NvlGpuStress.*NVLink.*Error Threshold Exceeded' -e 'NETIR_LINK_EVT.*Fatal' dgx/latest_log/run.log
