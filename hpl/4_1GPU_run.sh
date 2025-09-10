#!/bin/bash
#
target_nodes=(
GB200-DH420-A01-P2-GPU-[01-18]
GB200-DH420-B02-P2-GPU-[01-18]
GB200-DH420-D01-P2-GPU-[01-18]
GB200-DH420-D02-P2-GPU-[01-17]
GB200-DH420-E01-P2-GPU-[01-18]
GB200-DH420-E02-P2-GPU-[01-18]
GB200-DH420-I01-P2-GPU-[01-18]
GB200-DH420-I02-P2-GPU-[01-18]
GB200-DH420-J01-P2-GPU-[01-18]
GB200-DH420-J02-P2-GPU-[01-18]
GB200-DH420-K01-P2-GPU-[01-18]
GB200-DH420-L01-P2-GPU-[01-18]
)

all_hosts=($(scontrol show hostname $(echo ${target_nodes[*]}|tr ' ' ',')))
#echo ${#all_hosts[*]} ${all_hosts[*]} 
for i in ${all_hosts[*]}; do
  sbatch --reservation=xshang_8 \
    -N 1 -w $i -t 0:15:00 \
    --job-name=HPL \
    --output=${USER}-HPL-${i}-1GPU-%j.txt \
    hpl-1GPU.sbatch
done