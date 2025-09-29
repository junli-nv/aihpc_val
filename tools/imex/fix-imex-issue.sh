#!/bin/bash

target_groups=$1

## Fix IMEX issue manually
pdsh -R ssh -f 32 -R ssh -w ${target_nodes} <<- 'EOF'
date
systemctl disable nvidia-imex.service
systemctl stop nvidia-imex.service
rm -f /etc/nvidia-imex/nodes_config.cfg
touch /etc/nvidia-imex/nodes_config.cfg
systemctl stop cmd; systemctl restart nvidia-dcgm; sleep 10; systemctl start cmd
nvidia-smi -q | grep -E 'Bus Id|CliqueId|ClusterUUID'|paste - - -
EOF
sleep 70
cmsh -c "device;nvdomaininfo"|grep ${target_nodes%%-Node*}|awk '{print $3,$4,$5}'|sort|uniq -c
pdsh -R ssh -f 32 -R ssh -w ${target_nodes} <<- 'EOF'
systemctl enable nvidia-imex.service
wc -l /etc/nvidia-imex/nodes_config.cfg           #expected: 39
md5sum /etc/nvidia-imex/nodes_config.cfg          #expected: same on all 18 nodes
systemctl start nvidia-imex.service
systemctl status nvidia-imex.service|grep Active: #expected: running
EOF
