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
##badnode
GB200-DH420-B02-P2-GPU-06
##lower perf (<63TF)
GB200-DH420-B02-P2-GPU-07 #61.61F
## NV_ERR_INVALID_STATE - reboot will help
GB200-DH420-A02-P2-GPU-02
)

## Filter the nodes without issues, find out the bad nodes
pdsh -R ssh -w $(scontrol show hostname $(echo ${need_validate_nodes[*]}|tr ' ' ',')|paste -s -d ',') -x $(scontrol show hostname $(echo ${known_bad_nodes[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
bash /home/cmsupport/workspace/hc/checker.sh || true
EOF

a=(
GB200-DH420-A01-P2-GPU-[01-18]
GB200-DH420-A02-P2-GPU-[01,03-18]
GB200-DH420-B01-P2-GPU-[01-18]
GB200-DH420-B02-P2-GPU-[01-05,08-18]
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

pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d ',') <<- EOF
ipmitool raw 0x3c 0x74 100
EOF
pdsh -t 5 -u 30 -f 36 -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF' | tee /tmp/fans.txt
ipmitool sdr|grep RPM|awk '{print $3}'|paste -s -d ' '
EOF
sort -k2 -nr /tmp/fans.txt|tail -n 20

## Scatter nemo image to local disk
pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF'
mkdir -p /data; [ ! -f /data/nemo-25.04.rc2.m2.sqsh ] && nohup dd if=/home/cmsupport/workspace/nemo-25.04.rc2.m2.sqsh of=/data/nemo-25.04.rc2.m2.sqsh bs=1M oflag=direct &>/dev/null &
EOF
pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF'|dshbak -c
ps -ef|grep -w dd|grep -v grep|wc -l
EOF

pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF' |dshbak -c|sed 's:,GB200: GB200:g'|tee /tmp/a.txt
rm -f /var/lib/systemd/coredump/*
[ -f /data/nemo-25.04.rc2.m2.sqsh ] && echo IMG_OK || echo IMG_FAIL
blockdev --getsz /data/nemo-25.04.rc2.m2.sqsh
#dmesg -C
EOF

pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
uname -r
cat /proc/cmdline | tr ' ' '\n'|grep -v -E 'ip=|BOOT' | sort | paste -s -d ' '
EOF

target_nodes=(
GB200-DH420-A01-P2-GPU-[01-18] GB200-DH420-A02-P2-GPU-[01,03-18] GB200-DH420-B01-P2-GPU-[01-18] GB200-DH420-B02-P2-GPU-[01-05,08-18] GB200-DH420-C01-P2-GPU-[01-18] GB200-DH420-C02-P2-GPU-[01-18] GB200-DH420-D01-P2-GPU-[01-18] GB200-DH420-D02-P2-GPU-[01-18] GB200-DH420-E01-P2-GPU-[01-18] GB200-DH420-E02-P2-GPU-[01-18] GB200-DH420-I01-P2-GPU-[01-18] GB200-DH420-I02-P2-GPU-[01-18] GB200-DH420-J01-P2-GPU-[01-18] GB200-DH420-J02-P2-GPU-[01-18] GB200-DH420-K01-P2-GPU-[01-18] GB200-DH420-L01-P2-GPU-[01-18]
#GB200-DH430-A01-P3-GPU-[01-18] GB200-DH430-A02-P3-GPU-[01-18] GB200-DH430-B01-P3-GPU-[01-13,15-18] GB200-DH430-B02-P3-GPU-[01-18] GB200-DH430-C01-P3-GPU-[01-18] GB200-DH430-C02-P3-GPU-[01-18] GB200-DH430-D01-P3-GPU-[01-18] GB200-DH430-D02-P3-GPU-[01-08,10-18] GB200-DH430-M01-P3-GPU-[01-07,09-18] GB200-DH430-M02-P3-GPU-[01-18] GB200-DH430-N01-P3-GPU-[01-18] GB200-DH430-N02-P3-GPU-[01-18] GB200-DH430-O01-P3-GPU-[01-18] GB200-DH430-O02-P3-GPU-[01-12,14-18] GB200-DH430-P01-P3-GPU-[01-05,09-18] GB200-DH430-P02-P3-GPU-[01-18]
)
echo ${#target_nodes[*]} ${target_nodes[*]}

scontrol update nodename=$(echo ${target_nodes[*]}|tr ' ' ',') stat=undrain
scontrol show node $(echo ${target_nodes[*]}|tr ' ' ',') |grep -E 'NodeName|State|ReservationName'|paste - - -|grep -o State=.*|sort|uniq -c

## Per rack test - cover all the nodes
for r in ${target_nodes[*]}
do
  rack=$(echo $r|cut -c7-15)
  hosts=($(scontrol show hostname $r))
  step=16
  i=0; while [ $i -lt ${#hosts[*]} ]; do
    s0=$[i+1]
	  s1=$[i+step]
    #cat <<- EOF
    sbatch --reservation=junli_val \
      -N ${step} \
      -w $(echo "${hosts[*]} ${hosts[*]}"|cut -f${s0}-${s1} -d ' '|tr ' ' ',') \
      -t 13:00 \
      --job-name=NEMO-1R \
      --output=${USER}-HPL-1Rack-${rack}-${step}N-%j.txt \
      job.sbatch
#EOF
	i=${s1}
  done
done

## Cross rack test - find the best node sets
max=16
hosts=($(
for i in ${target_nodes[*]}; do
  tmp_hosts=($(scontrol show hostname ${i}))
  if [ ${#tmp_hosts[*]} -ge ${max} ]; then
    echo ${tmp_hosts[*]}|cut -f1-${max} -d' '
  else
    continue
  fi
done
))
echo ${#hosts[*]}
echo ${hosts[*]}

padding_hosts=($(echo $(scontrol show hostname $(echo ${target_nodes[*]}|tr ' ' ',')) ${hosts[*]}|tr ' ' '\n'|sort|uniq -c|grep -v ' 2 '|awk '{print $NF}'))
echo ${#padding_hosts[*]}
echo ${padding_hosts[*]}

## Remove the orphan enroot containers in case the last job be killed and slurm didn't reclaimed the container back
pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF'|dshbak -c
enroot list -f|grep pyxis && enroot remove -f $(enroot list -f|grep pyxis) || true
enroot list -f|grep pyxis||true
pkill -9 python &>/dev/null || true
ps -ef|grep python|grep -v -E 'torch|nemo'|grep -v grep || true
sync;sync;sync
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
EOF
#numactl -H|grep node.*free|grep -v ' 0 '|paste -s -d','

## FIXME: The better to wait 1min between each job
step=256 #32 64 128
i=0; while [ $i -lt ${#hosts[*]} ]; do
  s0=$[i+1]
  s1=$[i+step]
  t_hosts=($(echo ${hosts[*]} ${hosts[*]}|cut -f${s0}-${s1} -d ' '))
  t_racks=($(echo ${t_hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
  [ ${#t_racks[*]} -lt $[${step}/${max}] ] && break
  #jobname=${#t_racks[*]}Rack-$(echo ${t_racks[*]}|tr ' ' '_')
  
  ret=($(echo ${t_hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
  jobname=${#ret[*]}Rack-$(
  echo ${ret[*]}|tr ' ' '\n'|cut -f1 -d'-'|sort|uniq|while read i; do
    echo ${i}-$(echo ${ret[*]}|tr ' ' '\n' | grep $i|cut -f2 -d'-'|paste -s -d'_')
  done|paste -s -d'+'
  )
  #cat <<- EOF
  sbatch --reservation=junli_val \
    -N ${#t_hosts[*]} \
    -w "$(echo ${t_hosts[*]}|tr ' ' ',')" \
    -t 13:00 \
    --job-name=${jobname} \
    --output=${USER}-${jobname}-${#t_hosts[*]}N-%j.txt \
    job.sbatch
#EOF
  i=${s1}
done

## Cluster cover
step=256
t_hosts=($(echo ${hosts[*]} ${padding_hosts[*]}|tr ' ' '\n'|sort))
#echo ${#t_hosts[*]} ${t_hosts[*]}
t_racks=($(echo ${t_hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
#echo ${#t_racks[*]}
#jobname=CLUSTER_COVER-${step}N-$(echo ${t_racks[*]}|tr ' ' '_')
ret=($(echo ${t_hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
jobname=CLUSTER_COVER-(
  echo ${ret[*]}|tr ' ' '\n'|cut -f1 -d'-'|sort|uniq|while read i; do
    echo ${i}-$(echo ${ret[*]}|tr ' ' '\n' | grep $i|cut -f2 -d'-'|paste -s -d'_')
  done|paste -s -d'+'
  )
i=0; while [ $i -lt ${#t_hosts[*]} ]; do
  s0=$[i+1]
	s1=$[i+step]
  cat <<- EOF
  sbatch --reservation=junli_val \
    -N ${step} \
    -w $(echo "${t_hosts[*]} ${t_hosts[*]}"|cut -f${s0}-${s1} -d ' '|tr ' ' ',') \
    -t 13:00 \
    --job-name=${jobname} \
    --output=${USER}-${jobname}-%j.txt \
    job.sbatch
EOF
	i=${s1}
done

## Check results
for i in *Rack*.txt; do echo $i $(grep 'iteration 100/' $i|grep -o train_step_timing.*); done

plog-nemo(){
printf "%160s%30s%30s\n" FILENAME "train_step_timing(s)" "tflops_per_sec_per_gpu"
for i in *Rack*.txt; do
  ret=($(grep 'iteration 102/' $i|awk '{print $(NF-6),int($(NF-3))}'))
  if [ ${#ret[*]} -gt 0 ]; then
    printf "%160s%30s%30s\n" ${i##*/} ${ret[0]} ${ret[1]}
  else
    printf "%160s%30s%30s\n" ${i##*/} FAILED 0
  fi  
done|sort
}
plog-nemo | tee plog-memo.txt




