#!/bin/bash
#
target_nodes=$1
#target_nodes=GB200-DH420-L01-P2-GPU-[01-18]

## Collect compute trays' info
cmsh -c 'device; list -f type,hostname:40,category:40,ip:40 -t PhysicalNode' |grep PhysicalNode|grep -v node001|sort -k2|tee /cm/images/gb200-image/etc/nvidia-imex/compute_trays.txt

pdcp -R ssh -w ${target_nodes} /cm/images/gb200-image/etc/nvidia-imex/compute_trays.txt /etc/nvidia-imex/compute_trays.txt 

pdsh -R ssh -w ${target_nodes} <<- 'EOF'|dshbak -c
md5sum /etc/nvidia-imex/compute_trays.txt
wc -l /etc/nvidia-imex/compute_trays.txt
systemctl restart nvidia-imex
EOF

