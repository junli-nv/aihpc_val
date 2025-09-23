#!/bin/bash
#
hosts=(
#$(cat hosts.list | awk '{print $1}')
$(scontrol show hostname GB200-DH420-A01-P2-GPU-[01-18],GB200-DH420-A02-P2-GPU-[01-18],GB200-DH420-B01-P2-GPU-[01-18],GB200-DH420-B02-P2-GPU-[01-05,07-18],GB200-DH420-C01-P2-GPU-[01-18],GB200-DH420-C02-P2-GPU-[01-18],GB200-DH420-D01-P2-GPU-[01-18],GB200-DH420-D02-P2-GPU-[01-18],GB200-DH420-E01-P2-GPU-[01-18],GB200-DH420-E02-P2-GPU-[01-18],GB200-DH420-I01-P2-GPU-[01-18],GB200-DH420-I02-P2-GPU-[01-18],GB200-DH420-J01-P2-GPU-[01-18],GB200-DH420-J02-P2-GPU-[01-18],GB200-DH420-K01-P2-GPU-[01-18],GB200-DH420-L01-P2-GPU-[01-18])
)

work(){
  h=$1
  echo 'BMC_LOGS_BEGIN'  
  ./nodeeventlog $h
  echo 'BMC_LOGS_DONE'
  echo 'HMC_LOGS_BEGIN'
  ./nodeeventlog $h hmc
  echo 'HMC_LOGS_DONE'
}
export -f work

n=1; for i in ${hosts[*]}; do
  echo $i
  timeout 600 bash -c "work $i" > ./tmp/$i.txt &
  if [ $[n%50] -eq 0 ]; then
    wait
  fi
  n=$[n+1]
done

#grep PS_RUN_PWR_FAULT *|cut -f1 -d':'|sort|uniq -c
