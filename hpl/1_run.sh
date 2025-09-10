#!/bin/bash
#
if [ $# -ne 2 ]; then
  echo "Usage: $(basename $0) step nodelist"
  exit 0
fi

step=$1
target_nodes=$2
all_hosts=($(scontrol show hostname ${target_nodes}))
#echo ${#all_hosts[*]} ${all_hosts[*]} 
#
i=0; while [ $i -lt ${#all_hosts[*]} ]; do
  s0=$[i+1]
  s1=$[i+step]
  t_hosts=($(echo ${all_hosts[*]} ${all_hosts[*]}|cut -f${s0}-${s1} -d ' '))
  t_racks=($(echo ${t_hosts[*]}|tr ' ' '\n'|cut -c13-15|sort|uniq))
  jobname=${#t_racks[*]}Rack-$(echo ${t_racks[*]}|tr ' ' '_')
  #cat <<- EOF
  sbatch --reservation=xshang_8 \
    -N ${#t_hosts[*]} \
    -w "$(echo ${t_hosts[*]}|tr ' ' ',')" \
    -t 0:15:00 \
    --job-name=${jobname} \
    --output=${USER}-${jobname}-${#t_hosts[*]}N-%j.txt \
    hpl.slurm
#EOF
  i=${s1}
done