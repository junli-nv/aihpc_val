#!/bin/bash

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

clear(){
  hcas=($(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*));done))
  for dev in "${hcas[@]}"; do
    mlxlink -d $dev -p 1 -pc &>/dev/null
  done
}

query(){
  hcas=($(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*));done))
  for dev in "${hcas[@]}"; do
    link_downed=$(</sys/class/infiniband/${dev}/ports/1/counters/link_downed)
    symbol_error=$(</sys/class/infiniband/${dev}/ports/1/counters/symbol_error)
    #mlxlink -d ${dev} -c
    phys_state=$(cat /sys/class/infiniband/${dev}/ports/1/phys_state|tr -d ' ')
    stat=$(cat /sys/class/infiniband/${dev}/ports/1/state|tr -d ' ')
    echo ${dev}:phys_state=${phys_state},stat=${stat},link_downed=${link_downed},symbol_error=${symbol_error}
  done
}

action=$1
[ -z $action ] && action="query"
case ${action} in
"clear") 
  clear
  ;;
"query")
  query
  ;;
*)
  query
  ;;
esac