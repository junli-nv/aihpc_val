#!/bin/bash

if [ -z $1 ]; then
log_dir=./logs
else
log_dir=$1
fi

aly_results(){
  #find ${log_dir} -type f -name '*-HPL-*.txt'|while read i; do echo $i $(grep WC $i); done|tr -s ' '|sort -t'-' -k5 -n
  find ${log_dir} -type f -name '*N-*.txt'|while read i; do echo $i $(grep WC $i); done|tr -s ' '|sort -t'-' -k5 -n
}

tmpf=$(mktemp)
aly_results > $tmpf
gpu_per_node=4

printf "%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n" nodes "max(TF)" "min(TF)" "avg(TF)" "Loops" "Vari(%)" "per GPU(TF)"
for i in $(cat $tmpf|grep -o -- -.*N-|awk -F '-' '{print $(NF-1)}'|tr -d 'N'|sort|uniq|sort -n)
do
  ret=($(cat $tmpf | grep WC | grep -- -${i}N-|awk '{print $8/1000}' | sort -nr))
  [ ${#ret[*]} -eq 0 ] && continue
  avgs=($(echo ${ret[*]}|tr ' ' '\n'|awk 'BEGIN{sum=0}{sum+=$1}END{print sum/NR, sum/NR/gpus}' gpus=$[i*gpu_per_node]))
  vari=$(echo "scale=2; 100-${ret[-1]}*100/${ret[0]}"|bc)
  printf "%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n"  \
  $i ${ret[0]} ${ret[-1]} ${avgs[0]} ${#ret[*]} ${vari} ${avgs[1]}
done

ret=($(cat $tmpf | grep -v WC))
echo -e "\n\n\nWARN: ${#ret[*]} failed to run, details list: "
echo ${ret[*]}|tr ' ' '\n'
rm -f $tmpf

