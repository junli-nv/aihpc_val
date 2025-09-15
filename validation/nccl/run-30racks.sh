#!/bin/bash
#

a=(
GB200-POD1-A03-Node[01-18] GB200-POD1-A05-Node[01-18] GB200-POD1-A09-Node[01-18] GB200-POD1-A11-Node[01-18] GB200-POD1-A13-Node[01-18] GB200-POD1-A15-Node[01-18] GB200-POD1-A17-Node[01-18] GB200-POD1-B02-Node[01-18] GB200-POD1-B04-Node[01-18] GB200-POD1-B06-Node[01-18] GB200-POD1-B08-Node[01-11,13-18] GB200-POD1-B12-Node[01-18] GB200-POD1-B14-Node[01-18] GB200-POD1-B16-Node[01-18] GB200-POD2-E03-Node[01-18] GB200-POD2-E05-Node[01-18] GB200-POD2-E07-Node[01-05,07-18] GB200-POD2-E09-Node[01-18] GB200-POD2-E11-Node[01-18] GB200-POD2-E13-Node[01-18] GB200-POD2-E15-Node[01-18] GB200-POD2-E17-Node[01-18] GB200-POD2-F02-Node[01-18] GB200-POD2-F04-Node[01-18] GB200-POD2-F06-Node[01-18] GB200-POD2-F08-Node[01-18] GB200-POD2-F10-Node[01-18] GB200-POD2-F12-Node[01-18] GB200-POD2-F14-Node[01-18] GB200-POD2-F16-Node[01-18]
)
#GB200-POD1-B08-Node12
#GB200-POD2-E07-Node06

all_hosts=($(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')))
all_racks=($(echo ${all_hosts[*]}|tr ' ' '\n'|cut -c12-14|sort|uniq))
jobname=${#all_racks[*]}Rack-$(echo ${all_racks[*]}|tr ' ' '_')
sbatch --reservation=junli_val \
  -N ${#all_hosts[*]} \
  -w "$(echo ${all_hosts[*]}|tr ' ' ',')" \
  -t 10:00 \
  --job-name=${jobname} \
  --output=${USER}-${jobname}-${#all_hosts[*]}N-%j.txt \
  nccl.sh
