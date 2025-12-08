#!/bin/bash
#

module load slurm
hosts=(
$(scontrol show hostname $(sinfo -al|grep 'reserved.*junli_val'|awk '{print $NF}'))
)

for i in {0..9}
do
  for h in ${hosts[*]}
  do
    sbatch --reservation=junli_val \
      -N 1 \
      -w "${h}" \
      -t 2:30:00 \
      --requeue \
      --dependency=singleton \
      --job-name=MNUBERGEMM-${h} \
      --output=${USER}-MNUBERGEMEM-${h}-%j.txt \
      mnubergemm.sbatch
  done
done
