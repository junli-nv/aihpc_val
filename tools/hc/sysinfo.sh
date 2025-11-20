#!/bin/bash

## Place this script in /home/cmsupport/workspace/
NODELIST=$1
if [ -z ${NODELIST} ]; then
  NODELIST=${SLURM_JOB_NODELIST}
fi

module load slurm

hosts=($(scontrol show hostname $NODELIST))

export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no"

echo -e "\n########INFO: Check OS"
pdsh -t 5 -u 5 -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<< "uname -r; df -Th|grep /cm/node-installer &>/dev/null || echo 'OS is READY'" 2>/dev/null | dshbak -c 

echo -e "\n########INFO: Check CPU"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
lscpu|awk '/Architecture:/,/L3 cache:/{print $0}'|grep -E -v 'GHz|MHz'
cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor|sort|uniq -c
cat /sys/devices/system/cpu/cpu{1..71}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{ret=int(sum/NR/1000); if(500>ret){print "S0 freq FAILED", bios}else{print "S0 freq PASS", bios}}' bios=$(</sys/class/dmi/id/bios_date)
cat /sys/devices/system/cpu/cpu{72..143}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{ret=int(sum/NR/1000); if(500>ret){print "S1 freq FAILED", bios}else{print "S1 freq PASS", bios}}' bios=$(</sys/class/dmi/id/bios_date)
EOF

echo -e "\n########INFO: Check NUMA"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
numactl -H|grep size:|grep -v ' 0 MB'|awk '{print "N"$2"="int($(NF-1)/1000)"GB"}'|paste -s -d','
EOF

echo -e "\n########INFO: Check GPU basic"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi --format=csv --query-gpu gpu_bus_id,gpu_name,vbios_version,pstate,enforced.power.limit,ecc.errors.uncorrected.aggregate.total
EOF

echo -e "\n#########INFO: Check NVLINK status(Expected: 72 links are up)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi nvlink -s|grep '5[0-9].* GB/s'|wc -l
nvidia-smi --format=csv --query-gpu gpu_bus_id,fabric.state,fabric.status
EOF

echo -e "\n#########INFO: Check P2P status(Expected: All GPU are OK to each other)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi topo -p2p n|grep GPU[0-9].*OK
EOF

echo -e "\n########INFO: Check CUUID"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi -q | grep -E 'Bus Id|CliqueId|ClusterUUID'
EOF

echo -e "\n########INFO: Check IB devices status(Expected: All up and active)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ibstatus|grep -E 'Infiniband|state:'|paste - - -
EOF

echo -e "\n########INFO: Check IB Link Down status(Expected: No issue found)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ls -l /sys/class/infiniband|grep infiniband|awk -F'/' '{print $(NF-2),$NF}'|while read bdf dev; do ret=$(mlxlink -d $bdf -c|grep Recommendation|cut -f2- -d ':'|grep -v 'No issue was observed'||true); [ "X$ret" != "X" ] && echo "$dev:${ret}"; done|paste -s -d','
EOF

echo -e "\n########INFO: Check IFace device status(Expected: all nodes use the same interface connect to default gatewawy)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ip r sh|grep default|grep -o dev.*|cut -f2 -d' '
EOF

echo -e "\n########INFO: Check IMEX channel devices(Expected: At least one channel exist)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ls -1 /dev/nvidia-caps-imex-channels/
EOF

echo -e "\n########INFO: Check IMEX profile"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
grep -E "^(SERVER_PORT|IMEX_CMD_PORT|IMEX_CMD_ENABLED)=" /etc/nvidia-imex/config.cfg|paste -s -d ' '
EOF

echo -e "\n########INFO: Check IMEX nodes_config(Expected: file exist)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
md5sum /etc/nvidia-imex/nodes_config.cfg
EOF

echo -e "\n########INFO: Check IMEX service status(Expected: 2 ports up and service is active)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
netstat -lntp|grep -E ':(50000|50005) '|wc -l
systemctl is-active nvidia-imex.service || true
ls /cm/local/apps/slurm/var/*/*imex* 2>/dev/null||true
EOF

echo -e "\n#########INFO: Check IMEX readiness(Expected: imex is READY)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-imex-ctl -q || true
EOF

echo -e "\n########INFO: Check IMEX connection status(Expected: Node be in READY, all nodes connected and Domain UP)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-imex-ctl -N|awk '/Nodes:/,/Domain State:/{print $0}'|sed -e 's:\*: :g' -e 's:-: :g'
EOF

echo -e "\n########INFO: Check dmesg(Expected: No NV_ERR_*)"
pdsh -f 100 -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
dmesg --since "4 hour ago"|grep -o  NV_ERR_[^\]]*|sort|uniq
EOF
