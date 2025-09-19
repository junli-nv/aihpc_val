#!/bin/bash
#


module load slurm
hosts=(
$(scontrol show hostname $(sinfo -al|grep 'reserved.*junli_val'|awk '{print $NF}'))
)

jobname=DCGMI-$(date +"%Y%m%d%H%M%S")
logdir=logs/${jobname}
mkdir -p ${logdir}

#echo ${hosts[*]}
for h in ${hosts[*]}
do
  for level in 4 #1 2 3 4 p30m p2h
  do
    sbatch --reservation=junli_val \
      -N 1 \
      -w "${h}" \
      -t 2:00:00 \
      --job-name=${jobname} \
      --output=${logdir}/${USER}-${jobname}-${h}-r${level}-%j.txt \
      --export=LEVEL=${level} \
      dcgmi.sbatch
  done
done

# grep -i failed -r ./logs
