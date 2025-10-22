#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
kill -9 $(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits) &>/dev/null || true
systemctl stop cmd munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service
if [ $(lsof|grep /dev/nvidia|wc -l) -ne 0 ]; then
  kill -9 $(lsof|grep /dev/nvidia|awk '{print $2}'|sort|uniq) &>/dev/null
fi
nvidia-smi -r
systemctl start cmd munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service
