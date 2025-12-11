#!/bin/bash
#

module load slurm
hosts=(
$(scontrol show hostname $(sinfo -al|grep 'idle '|awk '{print $NF}'))
)

# for i in {0..9}
# do
#   for h in ${hosts[*]}
#   do
#     sbatch --reservation=junli_val \
#       -N 1 \
#       -w "${h}" \
#       -t 2:30:00 \
#       --requeue \
#       --dependency=singleton \
#       --job-name=MNUBERGEMM-${h} \
#       --output=${USER}-MNUBERGEMEM-${h}-%j.txt \
#       mnubergemm.sbatch
#   done
# done

scancel $(squeue|grep MNUBERGE|awk '{print $1}')
for i in {0..9}
do
  for h in ${hosts[*]}
  do
    timeout 155m \
    sbatch --wait \
      -N 1 \
      -w "${h}" \
      -t 2:30:00 \
      --requeue \
      --dependency=singleton \
      --job-name=MNUBERGEMM-${h} \
      --output=${USER}-MNUBERGEMEM-${h}-%j.txt \
      mnubergemm.sbatch &
  done
  wait
  pdsh -R ssh -f 32 -w $(echo ${hosts[*]} | tr ' ' ',') <<- EOF
${PWD}/../../tools/hc/checker.sh -e|grep -v PASS||true
EOF
done
