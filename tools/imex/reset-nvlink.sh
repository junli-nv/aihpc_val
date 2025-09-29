#!/bin/bash

### This script try to reset the down nvlink on fly by resetting the GPUs.
### If the script doesn't help, then a OS reboot needed.

## Define nodes to be checked
hosts=($(scontrol show hostname s03-p1-dgx-01-c[01-03,05-18],s04-p1-dgx-02-c[01-18]))
echo ${hosts[*]}

## Filter out the bad nodes
badnodes=(
$(
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF'|dshbak -c|grep dgx
nvidia-smi nvlink -s|grep '50 GB/s'|wc -l|grep -v -w 72||true
EOF
)
)
echo ${badnodes[*]}

scontrol update nodename=${badnodes[*]} stat=drain reason='nvlink down'

pdsh -R ssh -w ${badnodes[*]} <<- 'EOF'
systemctl stop cmd
systemctl stop slurmd
systemctl stop nvsm
systemctl stop nvidia-dcgm
systemctl stop nvidia-persistenced
systemctl stop nvidia-imex
lsof|grep nvidia2
EOF

pdsh -R ssh -w ${badnodes[*]} <<- 'EOF'
timeout 120 nvidia-smi -r
EOF

pdsh -R ssh -w ${badnodes[*]} <<- 'EOF'
nvidia-smi nvlink -s|grep '50 GB/s'|wc -l
EOF

pdsh -R ssh -w ${badnodes[*]} <<- 'EOF'
systemctl start nvidia-persistenced
systemctl start nvidia-dcgm
systemctl start nvsm
systemctl start slurmd
systemctl start cmd
EOF

cmsh -c 'device; nvdomaininfo'| grep Success|awk '{print $1":"$4}'|sort|uniq|dshbak -c

scontrol update nodename=${badnodes[*]} stat=resume