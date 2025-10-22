#!/bin/bash

kill -9 $(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits) &>/dev/null || true
systemctl stop cmd munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service
nvidia-smi -r
systemctl start cmd munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service
