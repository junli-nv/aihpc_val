#!/bin/bash

### Global wide IMEX
# [T06-HEAD-01->category[dgx-gb200]->services[nvidia-imex]]% show                                    
# Monitored                        yes                                             
# Autostart                        yes                                             
# Managed                          yes                                              
# [T06-HEAD-01->configurationoverlay[slurm-client-gpu]->roles[slurmclient]]% get imex 
# no

hosts=($(scontrol show hostname s03-p1-dgx-01-c[01-03,05-18],s04-p1-dgx-02-c[01-18]))

(
echo -e "\n########INFO: Check IMEX channel devices"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ls -1 /dev/nvidia-caps-imex-channels/
EOF

echo -e "\n########INFO: Check IMEX profile"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
md5sum /etc/nvidia-imex/nodes_config.cfg
grep -E "^(SERVER_PORT|IMEX_CMD_PORT|IMEX_CMD_ENABLED)=" /etc/nvidia-imex/config.cfg|paste -s -d ' '
EOF

echo -e "\n########INFO: Check IMEX service status"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
netstat -lntp|grep -E ':(50000|50005) '|wc -l
systemctl is-active nvidia-imex.service || true
ls -l  /cm/local/apps/slurm/var/*/*imex*|grep -o /cm.*
EOF
#Expected: nvidia-imex is up

echo -e "\n#########INFO: Check IMEX readiness"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-imex-ctl -q || true
nvidia-smi nvlink -s|grep '50 GB/s'|wc -l
nvidia-smi --format=csv --query-gpu gpu_bus_id,fabric.state,fabric.status
EOF
#Expected: All nodes be in READY and 72 links up on each node

echo -e "\n########INFO: Check CUUID"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
nvidia-smi -q | grep -E 'Bus Id|CliqueId|ClusterUUID'
EOF

echo -e "\n########INFO: Check IMEX connection status"
#ssh ${hosts[0]} nvidia-imex-ctl -N #Expected: Node be in READY, all nodes connected and Domain UP
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<< 'nvidia-imex-ctl -N|sed '1,11d''|dshbak -c 

echo -e "\n########INFO: Check IB devices status"
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
ibstatus|grep -E 'Infiniband|state:'|paste - - -
EOF
#Result Now: Only N/S eth wired, E/W IB disconnected.
) 2>/dev/null | tee /tmp/sysinfo.txt

cmsh -c 'device; nvdomaininfo'| grep Success|awk '{print $1":"$4}'|sort|uniq|dshbak -c
### Workaround the wrong CUUID collected by BCM. 
#----------------
#s04-p1-dgx-02-c[01-18]
#----------------
#cb23b835-48e3-4e55-b85e-c437ec8fe7f5
#----------------
#s03-p1-dgx-01-c[08,12,13,15]
#----------------
#41929a40-7f9b-440a-addd-bb7fad83e9e6
#s03-p1-dgx-01-c[01-03,05-07,09-11,14,16-18]
#----------------
#c46be145-35b5-4ffc-a93c-236b6d9e0daf
#----------------
### Reset the CUUID for s03:
# pdsh -R ssh -w s03-p1-dgx-01-c[01-18] <<- 'EOF'
# systemctl stop cmd; systemctl restart nvidia-dcgm; sleep 10; systemctl start cmd
# EOF
