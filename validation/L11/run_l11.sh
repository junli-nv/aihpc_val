#!/bin/bash

## https://apps.nvidia.com/PID/ContentLibraries/Detail/1127062
cd /home/cmsupport/workspace/629-24972-4975-FLD-50898-rev23

cp spec_gb200_nvl_72_2_4_compute_nodes_nvlgpustress_partner_mfg.json config_r02.json
## Modify config_r02.json

./partnerdiag --mfg --run_spec=config_r02.json --primary_diag_ip=10.135.8.2 --topology=topo_72x1.json --test=NvlGpuStress --no_bmc

grep 'Final Result:' partnerdiag.log
grep -e 'NvlGpuStress.*NVLink.*Error Threshold Exceeded' -e 'NETIR_LINK_EVT.*Fatal' run.log
