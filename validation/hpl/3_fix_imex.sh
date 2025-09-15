#!/bin/bash

target_nodes=$1
#target_nodes=GB200-DH420-L01-P2-GPU-[01-18]

pdcp -R ssh -w ${target_nodes} /cm/images/gb200-image/etc/nvidia-imex/compute_trays.txt /etc/nvidia-imex/compute_trays.txt 

pdsh -R ssh -w ${target_nodes} <<- 'EOF'|dshbak -c
md5sum /etc/nvidia-imex/compute_trays.txt
wc -l /etc/nvidia-imex/compute_trays.txt
systemctl restart nvidia-imex
EOF