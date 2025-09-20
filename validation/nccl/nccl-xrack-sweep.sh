#!/bin/bash
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no -o PreferredAuthentications=publickey"

need_validate_nodes=(
#$(sinfo -N|grep -E 'GB200-DH420-.*-P2|GB200-DH430-.*-P3'|awk '{print $1}'|paste -s -d ' ')
GB200-DH420-A01-P2-GPU-[01-18]
GB200-DH420-A02-P2-GPU-[01-18]
GB200-DH420-B01-P2-GPU-[01-18]
GB200-DH420-B02-P2-GPU-[01-18]
GB200-DH420-C01-P2-GPU-[01-18]
GB200-DH420-C02-P2-GPU-[01-18]
GB200-DH420-D01-P2-GPU-[01-18]
GB200-DH420-D02-P2-GPU-[01-18]
GB200-DH420-E01-P2-GPU-[01-18]
GB200-DH420-E02-P2-GPU-[01-18]
GB200-DH420-I01-P2-GPU-[01-18]
GB200-DH420-I02-P2-GPU-[01-18]
GB200-DH420-J01-P2-GPU-[01-18]
GB200-DH420-J02-P2-GPU-[01-18]
GB200-DH420-K01-P2-GPU-[01-18]
GB200-DH420-L01-P2-GPU-[01-18]
)

known_bad_nodes=(
##NVLINK
##IB DOWN
GB200-DH420-B02-P2-GPU-06
GB200-DH420-D02-P2-GPU-10
)

## Filter the nodes without issues, find out the bad nodes
pdsh -R ssh -w $(scontrol show hostname $(echo ${need_validate_nodes[*]}|tr ' ' ',')|paste -s -d ',') -x $(scontrol show hostname $(echo ${known_bad_nodes[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
bash /home/cmsupport/workspace/hc/checker.sh || true
EOF

a=(
GB200-DH420-A01-P2-GPU-[01-18] GB200-DH420-A02-P2-GPU-[01-18] GB200-DH420-B01-P2-GPU-[01-18] GB200-DH420-B02-P2-GPU-[01-05,07-18] GB200-DH420-C01-P2-GPU-[01-18] GB200-DH420-C02-P2-GPU-[01-18] GB200-DH420-D01-P2-GPU-[01-18] GB200-DH420-D02-P2-GPU-[01-18] GB200-DH420-E01-P2-GPU-[01-18] GB200-DH420-E02-P2-GPU-[01-18] GB200-DH420-I01-P2-GPU-[01-18] GB200-DH420-I02-P2-GPU-[01-18] GB200-DH420-J01-P2-GPU-[01-18] GB200-DH420-J02-P2-GPU-[01-18] GB200-DH420-K01-P2-GPU-[01-18] GB200-DH420-L01-P2-GPU-[01-18]
)

pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
uname -r
cat /proc/cmdline | tr ' ' '\n'|grep -v -E 'ip=|BOOT' | sort | paste -s -d ' '
EOF

scontrol update nodename=$(echo ${a[*]}|tr ' ' ',') stat=undrain
scontrol show node $(echo ${a[*]}|tr ' ' ',') |grep -E 'NodeName|State'|paste - -|grep -o State.*|sort|uniq -c

## Per rack test
for r in ${a[*]}
do
  rack=$(echo $r|cut -c7-15)
  hosts=($(scontrol show hostname $r))
  #cat <<- EOF
  for loop in {0..3}; do
  sbatch --reservation=junli_val \
    -N ${#hosts[*]} \
    -w $(echo "${hosts[*]}"|tr ' ' ',') \
    -t 10:00 \
    --job-name=HPL-1R \
    --output=${USER}-NCCL-1Rack-${rack}-${#hosts[*]}N-%j.txt \
    nccl.sbatch
  done
#EOF
done

for i in $(ls -1rth *.txt); do
  printf "%30s%20s\n" $i $(grep 17179869184.*float $i|awk '{print $8}')
done|sort

plog-1rack(){
printf "%20s%10s%20s%20s%20s%20s%20s\n"  RACK "Loop#" "MAX(GB/S)" "MIN(GB/s)" "AVG(GB/s)" "Vari(%)"
racks=($(ls -1 *.txt|cut -c17-25|sort|uniq))
for i in ${racks[*]}; do
  ret=($(grep 17179869184.*float *-$i-*.txt|awk '{print $9}'|sort -nr))
  if [ ${#ret[*]} -gt 0 ]; then
    avg=$(echo ${ret[*]}|tr ' ' '\n'|awk 'BEGIN{sum=0}{sum+=$1}END{printf("%.2f\n", sum/NR)}')
    vari=$(echo | awk '{printf("%.2f\n", 100*(1-a/b))}' a=${ret[-1]} b=${ret[0]})
    printf "%20s%10s%20s%20s%20s%20s%20s\n" ${i} ${#ret[*]} ${ret[0]} ${ret[-1]} ${avg} ${vari}
  fi
done
}
plog-1rack | tee plog-1rack.log

max=16
hosts=($(
for i in ${a[*]}; do
  b=($(scontrol show hostname ${i}))
  if [ ${#b[*]} -ge ${max} ]; then
    echo ${b[*]}|cut -f1-${max} -d' '
  else
    continue
  fi
done
))
echo ${#hosts[*]}
echo ${hosts[*]}

#jobname=$[${#hosts[*]}/${max}]Rack-$(echo ${hosts[*]}|tr ' ' '\n'|cut -c13-15|sort|uniq|paste -s -d'_')
ret=($(echo ${hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
jobname=${#ret[*]}Rack-$(
  echo ${ret[*]}|tr ' ' '\n'|cut -f1 -d'-'|sort|uniq|while read i; do
    echo ${i}-$(echo ${ret[*]}|tr ' ' '\n' | grep $i|cut -f2 -d'-'|paste -s -d'_')
  done|paste -s -d'+'
  )
sbatch --reservation=junli_val \
  -N ${#hosts[*]} \
  -w "$(echo ${hosts[*]}|tr ' ' ',')" \
  -t 10:00 \
  --job-name=${jobname} \
  --output=${USER}-${jobname}-${#hosts[*]}N-%j.txt \
  nccl.sh

n=2; while [ $n -le $[${#hosts[*]}/${max}] ]; do
  #echo $n
  thosts=($(echo ${hosts[*]}|cut -f1-$[${max}*$n] -d ' '))
  #echo ${#thosts[*]} ${thosts[*]}
  jobname=${n}Rack-$(echo ${thosts[*]}|tr ' ' '\n'|cut -c13-15|sort|uniq|paste -s -d'_')
  sbatch --reservation=junli_val \
    -N ${#thosts[*]} \
    -w "$(echo ${thosts[*]}|tr ' ' ',')" \
    -t 10:00 \
    --job-name=${jobname} \
    --output=${USER}-${jobname}-${#thosts[*]}N-%j.txt \
  nccl.sh
  n=$[n*2]
done

## Full run with all nodes (imbalance mostly)
all_hosts=($(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')))
all_racks=($(echo ${all_hosts[*]}|tr ' ' '\n'|cut -c13-15|sort|uniq))
jobname=${#all_racks[*]}Rack-$(echo ${all_racks[*]}|tr ' ' '_')
sbatch --reservation=junli_val \
  -N ${#all_hosts[*]} \
  -w "$(echo ${all_hosts[*]}|tr ' ' ',')" \
  -t 10:00 \
  --job-name=${jobname} \
  --output=${USER}-${jobname}-${#all_hosts[*]}N-%j.txt \
  nccl.sh

for i in $(ls -1rth *.txt); do
  echo $i
  cat $i|grep -o  NET/IB.*OOB|sort|uniq -c
  grep 17179869184.*float $i|awk '{print $8}'
done

plog-xrack(){
for i in $(ls -1rth *.txt); do
  printf "# %160s%20s\n" $i $(grep 17179869184.*float $i|awk '{print $8}')
done|sort
}
plog-xrack|tee plog-xrack.log

