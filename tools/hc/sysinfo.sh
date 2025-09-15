#!/bin/bash

## Place this script in /home/cmsupport/workspace/
NODELIST=$1
if [ -z ${NODELIST} ]; then
  NODELIST=${SLURM_JOB_NODELIST}
fi

module load slurm

hosts=($(scontrol show hostname $NODELIST))

echo -e "\n########INFO: Check CPU"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
lscpu|awk '/Architecture:/,/L3 cache:/{print $0}'|grep -E -v 'GHz|MHz'
cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor|sort|uniq -c
cat /sys/devices/system/cpu/cpu{1..71}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{ret=int(sum/NR/1000); if(500>ret){print "S0 freq FAILED", bios}else{print "S0 freq PASS", bios}}' bios=$(</sys/class/dmi/id/bios_date)
cat /sys/devices/system/cpu/cpu{72..143}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{ret=int(sum/NR/1000); if(500>ret){print "S1 freq FAILED", bios}else{print "S1 freq PASS", bios}}' bios=$(</sys/class/dmi/id/bios_date)
EOF

echo -e "\n########INFO: Check NUMA"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
numactl -H|grep size:|grep -v ' 0 MB'|awk '{print "N"$2"="int($(NF-1)/1000)"GB"}'|paste -s -d','
EOF

echo -e "\n########INFO: Check GPU basic"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi --format=csv --query-gpu gpu_bus_id,gpu_name,vbios_version,pstate,enforced.power.limit,ecc.errors.uncorrected.aggregate.total
EOF

echo -e "\n#########INFO: Check NVLINK status(Expected: 72 links are up)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi nvlink -s|grep '5[0-9].* GB/s'|wc -l
nvidia-smi --format=csv --query-gpu gpu_bus_id,fabric.state,fabric.status
EOF

echo -e "\n#########INFO: Check P2P status(Expected: All GPU are OK to each other)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi topo -p2p n|grep GPU[0-9].*OK
EOF

echo -e "\n########INFO: Check CUUID"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi -q | grep -E 'Bus Id|CliqueId|ClusterUUID'
EOF

echo -e "\n########INFO: Check IB devices status(Expected: Only N/S eth wired, E/W IB disconnected)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ibstatus|grep -E 'Infiniband|state:'|paste - - -
EOF

echo -e "\n########INFO: Check IMEX channel devices(Expected: At least one channel exist)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ls -1 /dev/nvidia-caps-imex-channels/
EOF

echo -e "\n########INFO: Check IMEX profile"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
grep -E "^(SERVER_PORT|IMEX_CMD_PORT|IMEX_CMD_ENABLED)=" /etc/nvidia-imex/config.cfg|paste -s -d ' '
EOF

echo -e "\n########INFO: Check IMEX nodes_config(Expected: file exist)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
md5sum /etc/nvidia-imex/nodes_config.cfg
EOF

echo -e "\n########INFO: Check IMEX service status(Expected: 2 ports up and service is active)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
netstat -lntp|grep -E ':(50000|50005) '|wc -l
systemctl is-active nvidia-imex.service || true
ls /cm/local/apps/slurm/var/*/*imex* 2>/dev/null||true
EOF

echo -e "\n#########INFO: Check IMEX readiness(Expected: imex is READY)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-imex-ctl -q || true
EOF

echo -e "\n########INFO: Check IMEX connection status(Expected: Node be in READY, all nodes connected and Domain UP)"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-imex-ctl -N|sed '1,11d'
EOF


