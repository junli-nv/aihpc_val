#!/bin/bash

systemctl stop cmd munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service
nvidia-smi -r
systemctl start cmd munge.service slurmd.service nvidia-persistenced.service nvidia-dcgm.service nvidia-imex.service
