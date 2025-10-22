#!/bin/bash

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

clear(){
  lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*));done|while read dev in ${hcas[*]}; do mlxlink -d $dev -p 1 -pc &>/dev/null; done
}

query(){
lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*));done|while read dev in ${hcas[*]}; do link_downed=$(</sys/class/infiniband/${dev}/ports/1/counters/link_downed); symbol_error=$(</sys/class/infiniband/${dev}/ports/1/counters/symbol_error); [[ ${link_downed} -ne 0 || ${symbol_error} -ne 0 ]] && echo ${dev}:link_downed=${link_downed},symbol_error=${symbol_error}; done
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