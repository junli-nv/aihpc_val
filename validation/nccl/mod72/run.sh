#!/bin/bash

#Set fan to max
pdsh -f 100 -R ssh -w GB200-POD1-A[03,05,07,09,11,13,15,17]-Node[01-18],GB200-POD1-B[02,04,06,08,10,12,14,16]-Node[01-18],GB200-POD2-E[03,05,07,09,11,13,15,17]-Node[01-18],GB200-POD2-F[02,04,06,08,10,12,14,16]-Node[01-18] <<- EOF
ipmitool raw 0x3c 0x74 100
EOF
## Check fan speed
pdsh -t 5 -u 30 -f 100 -R ssh -w GB200-POD1-A[03,05,07,09,11,13,15,17]-Node[01-18],GB200-POD1-B[02,04,06,08,10,12,14,16]-Node[01-18],GB200-POD2-E[03,05,07,09,11,13,15,17]-Node[01-18],GB200-POD2-F[02,04,06,08,10,12,14,16]-Node[01-18] <<- 'EOF' | tee /tmp/fans.txt
ipmitool sdr|grep RPM|awk '{print $3}'|paste -s -d ' '
EOF
sort -k2 -nr /tmp/fans.txt|tail -n 20

## Filter the nodes without issues
ssh GB200-POD1-A03-Node01 ibdiagnet -pc
pdsh -R ssh -w $(sinfo -al|awk '/reserved.*junli_val /{print $NF}') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
bash /home/cmsupport/workspace/hc/checker.sh || true
EOF

a=(
GB200-POD1-A03-Node[01-18] GB200-POD1-A05-Node[01-18] GB200-POD1-A07-Node[01-18] GB200-POD1-A09-Node[01-18] GB200-POD1-A11-Node[01-18] GB200-POD1-A13-Node[01-18] GB200-POD1-A15-Node[01-18] GB200-POD1-A17-Node[01-18] GB200-POD1-B02-Node[01-18] GB200-POD1-B04-Node[01-18] GB200-POD1-B06-Node[01-18] GB200-POD1-B08-Node[01-18] GB200-POD1-B10-Node[01-18] GB200-POD1-B12-Node[01-18] GB200-POD1-B14-Node[01-18]
GB200-POD1-B16-Node[01-18] 
GB200-POD2-E03-Node[01-18] GB200-POD2-E05-Node[01-18] GB200-POD2-E07-Node[01-18] GB200-POD2-E09-Node[01-18] GB200-POD2-E11-Node[01-18] GB200-POD2-E13-Node[01-18] GB200-POD2-E15-Node[01-18] GB200-POD2-E17-Node[01-18] GB200-POD2-F02-Node[01-18] GB200-POD2-F04-Node[01-18] GB200-POD2-F06-Node[01-18] GB200-POD2-F08-Node[01-18] GB200-POD2-F10-Node[01-18] GB200-POD2-F12-Node[01-18] GB200-POD2-F14-Node[01-18] GB200-POD2-F16-Node[01-18]
)

scontrol show node $(echo ${a[*]}|tr ' ' ',') |grep -E 'NodeName|State|ReservationName'|paste - - -|grep -o State=.*|sort|uniq -c

pdsh -R ssh -w $(echo ${a[*]}|tr ' ' ',') <<- 'EOF'|dshbak -c
bash /home/cmsupport/workspace/hc/checker.sh || true
EOF

for i in ${a[*]}
do
  rack=$(echo $i|cut -c1-14)
  hosts=($(scontrol show hostname $i))
#cat <<- EOF
  sbatch --reservation=junli_val \
    -N ${#hosts[*]} \
    -w "${i}" \
    -t 10:00 \
    --job-name=${rack} \
    --output=${USER}-${rack}-${#hosts[*]}N-%j.txt \
    nccl-AR.sh
#EOF
done

logdir=$PWD/logs
mkdir -p $logdir

squeue|grep root|awk '{print $1}'|xargs -I {} scancel {}

# for i in $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')); do
#   sbatch --reservation=junli_val \
#     -N 1 \
#     -w "${i}" \
#     -t 10:00 \
#     --job-name=${i} \
#     --output=$logdir/${USER}-NCCL-${i}-1N-%j.txt \
#     nccl-loopback.sh
# done
# 
# for i in *-1N-*.txt; do
#   #$(cat $i | grep -o NET/IB.*|sort|uniq -c) 
#   echo "${i##*/} $(cat $i | grep float.*sum | awk '{print $8}')"
# done | sort -k2 -nr

max=18
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

## Full run with nodes balance
jobname=$[${#hosts[*]}/${max}]Rack-$(echo ${hosts[*]}|tr ' ' '\n'|cut -c12-14|sort|uniq|paste -s -d'_')
sbatch --reservation=junli_val \
  -N ${#hosts[*]} \
  -w "$(echo ${hosts[*]}|tr ' ' ',')" \
  -t 10:00 \
  --job-name=${jobname} \
  --output=$logdir/${USER}-${jobname}-${#hosts[*]}N-%j.txt \
  nccl-mod72.sh

## Scale by Rack
n=2; while [ $n -le $[${#hosts[*]}/${max}] ]; do
  #echo $n
  thosts=($(echo ${hosts[*]}|cut -f1-$[${max}*$n] -d ' '))
  #echo ${#thosts[*]} ${thosts[*]}
  jobname=${n}Rack-$(echo ${thosts[*]}|tr ' ' '\n'|cut -c12-14|sort|uniq|paste -s -d'_')
  sbatch --reservation=junli_val \
    -N ${#thosts[*]} \
    -w "$(echo ${thosts[*]}|tr ' ' ',')" \
    -t 10:00 \
    --job-name=${jobname} \
    --output=$logdir/${USER}-${jobname}-${#thosts[*]}N-%j.txt \
  nccl-mod72.sh
  n=$[n+1]
done

## Full run with all nodes (imbalance mostly)
all_hosts=($(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')))
all_racks=($(echo ${all_hosts[*]}|tr ' ' '\n'|cut -c12-14|sort|uniq))
jobname=${#all_racks[*]}Rack-$(echo ${all_racks[*]}|tr ' ' '_')
sbatch --reservation=junli_val \
  -N ${#all_hosts[*]} \
  -w "$(echo ${all_hosts[*]}|tr ' ' ',')" \
  -t 10:00 \
  --job-name=${jobname} \
  --output=${USER}-${jobname}-${#all_hosts[*]}N-%j.txt \
  nccl-mod72.sh

for i in $(ls -1rth *Rack*.txt); do
   for cmd in reduce_scatter_perf all_reduce_perf all_gather_perf alltoall_perf; do
   cat $i|awk "/INFO: ${cmd} BEGIN/,/INFO: ${cmd} DONE/{print \$0}" \
     &> LOG_${cmd}_N$(echo $i|awk -F'-' '{print $(NF-1)}'|tr -d 'N')n4.txt
   done
done
rm -rf ../oci-nccl-acceptance-test/logs/
mkdir -p ../oci-nccl-acceptance-test/logs
cp -v LOG_*N576n4.txt ../oci-nccl-acceptance-test/logs/
cd ../oci-nccl-acceptance-test/
rm -f *.png data_full.pkl
source venv/bin/activate
python parse_nccl_test_output.py -m
python analyze_results.py -m data_full.pkl -n ib -d 32 -b 50000.0 -t 0.95

aly(){
echo reduce_scatter_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: reduce_scatter_perf BEGIN/,/INFO: reduce_scatter_perf DONE/{print $0}'|grep 'float.*sum'|awk '{print $8}'|sort -n|tail -n1)
done
echo all_reduce_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: all_reduce_perf BEGIN/,/INFO: all_reduce_perf DONE/{print $0}'|grep 'float.*sum'|awk '{print $8}'|sort -n|tail -n1)
done
echo all_gather_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: all_gather_perf BEGIN/,/INFO: all_gather_perf DONE/{print $0}'|grep 'float.*none'|awk '{print $8}'|sort -n|tail -n1)
done
echo alltoall_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: alltoall_perf BEGIN/,/INFO: alltoall_perf DONE/{print $0}'|grep 'uint8.*none'|awk '{print $8}'|sort -n|tail -n1)
done
}
aly

