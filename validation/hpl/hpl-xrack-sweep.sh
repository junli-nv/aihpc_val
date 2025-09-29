#!/bin/bash

module load slurm
jobname=HPL-$(date +"%Y%m%d%H%M%S")
logdir=logs/${jobname}
mkdir -p ${logdir}

cd /home/cmsupport/workspace/hpl

mkdir /var/www/html/junli
mount -o bind /home/cmsupport/workspace /var/www/html/junli
#http://10.136.204.4/junli/hpl/

################################################################################

export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no"

need_validate_nodes=(
#$(sinfo -N|grep 420|grep P2|awk '{print $1}')
#$(sinfo -N|grep 430|grep P3|awk '{print $1}')
#$(sinfo -N|grep 410|grep P1|awk '{print $1}')
$(sinfo -N|grep 440|grep P4|awk '{print $1}')
)

pdsh -R ssh -w $(scontrol show hostname $(echo ${need_validate_nodes[*]}|tr ' ' ',')|paste -s -d ',') <<- EOF
ipmitool raw 0x3c 0x74 100
EOF
pdsh -t 5 -u 30 -f 36 -R ssh -w $(scontrol show hostname $(echo ${need_validate_nodes[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF' | tee /tmp/fans.txt
ipmitool sdr|grep RPM|awk '{print $3}'|paste -s -d ' '
EOF
sort -k2 -nr /tmp/fans.txt|tail -n 20

known_bad_nodes=(
##lower perf
GB200-DH430-C02-P3-GPU-13 #62.21
GB200-DH420-B02-P2-GPU-07 #61.61
#GB200-DH440-N01-P4-GPU-04 #61.63
#GB200-DH440-M02-P4-GPU-16 #60.57
#GB200-DH440-O02-P4-GPU-17 #56.28
#GB200-DH440-D02-P4-GPU-02 #34.60
GB200-DH440-P02-P4-GPU-08 #61.92
GB200-DH440-O02-P4-GPU-07 #52.64
#
GB200-DH440-A02-P4-GPU-10 #64.88
GB200-DH440-N02-P4-GPU-10 #64.65
GB200-DH440-N02-P4-GPU-17 #64.50 #DOWN during HPL
#GB200-DH440-B01-P4-GPU-03 # 65.83
GB200-DH440-C02-P4-GPU-04 # 65.78
#
#NVLINK
GB200-DH440-B01-P4-GPU-10
##ECC Error
GB200-DH420-A01-P2-GPU-14
##DISK error
#GB200-DH420-B01-P2-GPU-13
#GB200-DH420-A01-P2-GPU-07
#GB200-DH420-C01-P2-GPU-10
##Residual error -> With NCCL_MNNVL_ENABLE=1, this may make the HPL hang.
GB200-DH420-B01-P2-GPU-07
GB200-DH430-M01-P3-GPU-16
##DOWN
)

## Filter the nodes without issues, find out the bad nodes
pdsh -f 100 -R ssh -w $(scontrol show hostname $(echo ${need_validate_nodes[*]}|tr ' ' ',')|paste -s -d ',') -x $(scontrol show hostname $(echo ${known_bad_nodes[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
# dmesg -C
bash /home/cmsupport/workspace/hc/checker.sh || true
rm -f /var/lib/systemd/coredump/*
EOF

a=(
#GB200-DH420-A01-P2-GPU-[01-13,15-18] GB200-DH420-A02-P2-GPU-[01-14,16-18] GB200-DH420-B01-P2-GPU-[01-06,08-18] GB200-DH420-B02-P2-GPU-[01-06,08-18] GB200-DH420-C01-P2-GPU-[01-18] GB200-DH420-C02-P2-GPU-[01-12,14-18] GB200-DH420-D01-P2-GPU-[01-18] GB200-DH420-D02-P2-GPU-[01-18] GB200-DH420-E01-P2-GPU-[01-18] GB200-DH420-E02-P2-GPU-[01-17] GB200-DH420-I01-P2-GPU-[01-18] GB200-DH420-I02-P2-GPU-[01-16,18] GB200-DH420-J01-P2-GPU-[01-18] GB200-DH420-J02-P2-GPU-[01-18] GB200-DH420-K01-P2-GPU-[01-18] GB200-DH420-L01-P2-GPU-[01-18]
#
#GB200-DH430-A01-P3-GPU-[01-18] GB200-DH430-A02-P3-GPU-[01-18] GB200-DH430-B01-P3-GPU-[01-18] GB200-DH430-B02-P3-GPU-[01-18] GB200-DH430-C01-P3-GPU-[01-18] GB200-DH430-C02-P3-GPU-[01-12,14-18] GB200-DH430-D01-P3-GPU-[01-18] GB200-DH430-D02-P3-GPU-[01-18] GB200-DH430-M01-P3-GPU-[01-15,17-18] GB200-DH430-M02-P3-GPU-[01-18] GB200-DH430-N01-P3-GPU-[01-18] GB200-DH430-N02-P3-GPU-[01-18] GB200-DH430-O01-P3-GPU-[01-18] GB200-DH430-O02-P3-GPU-[01-18] GB200-DH430-P01-P3-GPU-[01-18] GB200-DH430-P02-P3-GPU-[01-18]
#
#GB200-DH410-A01-P1-GPU-[01-18] GB200-DH410-A02-P1-GPU-[01-18] GB200-DH410-B01-P1-GPU-[01-18] GB200-DH410-B02-P1-GPU-[01-18] GB200-DH410-C01-P1-GPU-[01-18] GB200-DH410-C02-P1-GPU-[01-18] GB200-DH410-D01-P1-GPU-[01-18] GB200-DH410-D02-P1-GPU-[01-18] GB200-DH410-M01-P1-GPU-[01-18] GB200-DH410-M02-P1-GPU-[01-18] GB200-DH410-N01-P1-GPU-[01-18] GB200-DH410-N02-P1-GPU-[01-18]GB200-DH410-O01-P1-GPU-[01-18] GB200-DH410-O02-P1-GPU-[01-18] GB200-DH410-P01-P1-GPU-[01-18] GB200-DH410-P02-P1-GPU-[01-18]
#
GB200-DH440-A01-P4-GPU-[01-05,07-18] GB200-DH440-A02-P4-GPU-[01-18] GB200-DH440-B01-P4-GPU-[01-09,11-18] GB200-DH440-B02-P4-GPU-[01-18] GB200-DH440-C01-P4-GPU-[01-18] GB200-DH440-C02-P4-GPU-[01-18] GB200-DH440-D01-P4-GPU-[01-18] GB200-DH440-D02-P4-GPU-[01-18] GB200-DH440-M01-P4-GPU-[01-18] GB200-DH440-M02-P4-GPU-[01-18] GB200-DH440-N01-P4-GPU-[01-18] GB200-DH440-N02-P4-GPU-[01-18] GB200-DH440-O01-P4-GPU-[01-18] GB200-DH440-O02-P4-GPU-[01-06,08-18] GB200-DH440-P01-P4-GPU-[01,03-14,16-18] GB200-DH440-P02-P4-GPU-[01-07,09-12,14-18]
)
echo ${#a[*]} ${a[*]}

pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
bash /home/cmsupport/workspace/hc/checker.sh || true
uname -r
cat /proc/cmdline | tr ' ' '\n'|grep -v -E 'ip=|BOOT' | sort | paste -s -d ' '
EOF

scontrol update nodename=$(echo ${a[*]}|tr ' ' ',') stat=undrain
scontrol show node $(echo ${a[*]}|tr ' ' ',') |grep -E 'NodeName|State'|paste - -|grep -o State.*|sort|uniq -c

## Per Node test
all_hosts=($(scontrol show hostname $(echo ${a[*]}|tr ' ' ',') ))
echo ${#all_hosts[*]} ${all_hosts[*]}
for i in {0..3}; do
for h in ${all_hosts[*]}; do
sbatch --reservation=junli_val \
    -N 1 \
    -w "${h}" \
    -t 5:00 \
    --job-name=HPL-1N \
    --output=${USER}-HPL-1N-${h}-%j.txt \
    hpl.sbatch
done
done

squeue|grep HPL

plog-1node | tee plog-1node.log
sort -k6 -nr plog-1node.log|tail -n 30
grep 'Ax-b.*_oo.*N.*=' *.txt|grep -v PASSED ##Find the nodes met residual error 

rm -f /tmp/tmp.log
for i in *-HPL-1N-*; do
echo $(echo $i|cut -c13-37) $(cat $i|grep WARNING:|grep -o Temp:.*|cut -f2 -d' '|sort -nr|head -n 1)
done|tee /tmp/tmp.log
cat /tmp/tmp.log | sort -k2 -n | tail -n 30
cat /tmp/tmp.log|awk '{print $1}'|sort|uniq|while read i; do
t=($(cat /tmp/tmp.log|grep ${i}|sed -e "s:${i}::"|paste -s -d' '))
[ ${#t[*]} -ne 0 ] && echo ${i} ${t[*]}
done|tee tlog-1node.log
less tlog-1node.log

## Per rack test
for r in ${a[*]}
do
  rack=$(echo $r|cut -c7-15)
  hosts=($(scontrol show hostname $r))
  step=${#hosts[*]}
  if [[ ${#hosts[*]} -ge 18 ]]; then
    step=18
  elif [[ ${#hosts[*]} -ge 16 ]]; then
    step=16
  elif [[ ${#hosts[*]} -ge 8 ]]; then
    step=8
  elif [[ ${#hosts[*]} -ge 4 ]]; then
    step=4
  elif [[ ${#hosts[*]} -ge 2 ]]; then
    step=2
  else
    step=1
  fi
  i=0; while [ $i -lt ${#hosts[*]} ]; do
    s0=$[i+1]
	  s1=$[i+step]
    #cat <<- EOF
    #for loop in {0..3}; do
    sbatch --reservation=junli_val \
      -N ${step} \
      -w $(echo "${hosts[*]} ${hosts[*]}"|cut -f${s0}-${s1} -d ' '|tr ' ' ',') \
      -t 20:00 \
      --job-name=HPL-1R \
      --output=${USER}-HPL-1Rack-${rack}-${step}N-%j.txt \
      hpl.sbatch
    #done
#EOF
	i=${s1}
  done
done

plog-1rack | tee plog-1rack.log

## Cross rack test
##Use the first $max elements per rack
max=16
hosts=($(
for i in ${a[*]}; do
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

##Use the last $max elements per rack
hosts=($(
for i in ${a[*]}; do
  tmp_hosts=($(scontrol show hostname ${i}))
  if [ ${#tmp_hosts[*]} -ge ${max} ]; then
    echo ${tmp_hosts[*]}|tr ' ' '\n'|tac|paste -s -d' '|cut -f1-${max} -d' '
  else
    continue
  fi
done
))
echo ${#hosts[*]}
echo ${hosts[*]}

padding_hosts=(
$(echo ${all_hosts[*]} ${hosts[*]} | tr ' ' '\n' | sort | uniq -c | grep -v -w 2|awk '{print $NF}')
)
echo ${#padding_hosts[*]} ${padding_hosts[*]}

#squeue | grep $USER | awk '{print $1}'|xargs -I {} scancel {}

## Step run to cover all the nodes
step=512 #32 64 128 256
#for loop in {0..5}; do
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
    -t 100:00 \
    --job-name=${jobname} \
    --output=${USER}-${jobname}-${#t_hosts[*]}N-%j.txt \
    hpl.slurm
#EOF
  i=${s1}
done
#done

watch -n 3 '
for i in *.txt; do echo $i $(grep Prog= $i|tail -n 1); done
'

plog-xRack|tee plog-xRack.log
# To view rack coverage
cat plog-xRack.log|grep 2Rack|grep -v FAILED|awk '{print $1}'|cut -c12-18|tr '_' '\n'|sort|uniq -c

## Cluster cover
step=256
t_hosts=($(echo ${all_hosts[*]}))
#echo ${#t_hosts[*]} ${t_hosts[*]}
t_racks=($(echo ${t_hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
#echo ${#t_racks[*]}
jobname=CLUSTER_COVER-${step}N-$(echo ${t_racks[*]}|tr ' ' '_')
i=0; while [ $i -lt ${#t_hosts[*]} ]; do
  s0=$[i+1]
	s1=$[i+step]
  #cat <<- EOF
  sbatch --reservation=junli_val \
    -N ${step} \
    -w $(echo "${t_hosts[*]} ${t_hosts[*]}"|cut -f${s0}-${s1} -d ' '|tr ' ' ',') \
    -t 13:00 \
    --job-name=${jobname} \
    --output=${USER}-${jobname}-%j.txt \
    hpl.slurm
#EOF
	i=${s1}
done


grep WARNING.*HPL_OOC_MODE= *.txt
# squeue| grep ${USER}| awk '{print $1}'|xargs -I {} scontrol update jobid={} timelimit=10:00
# squeue| grep ${USER}| awk '{print $1}'|xargs -I {} scancel {}

pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF'|dshbak -c
bash /home/cmsupport/workspace/hc/checker.sh
EOF

