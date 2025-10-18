#!/bin/bash

set_cpu_freq_userspace(){
  for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo userspace > $i; done
  for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo 3330000 > $i; done
  for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do echo 3000000 > $i; done
  for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed; do echo 3200000 > $i; done
  echo 0 > /sys/devices/system/cpu/cpufreq/boost
  ret=($(cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq|sort -n)); echo CPUFREQ: "MIN=$[${ret[0]}/1000] MAX=$[${ret[-1]}/1000]"
}

global_status=0
reason=""

extra_check=0
dry_run=0
options=d,e,h
optionl=dry-run,--extra-check,help
OPTS=$(getopt -a -n $0 --options $options --longoptions $optionl -- "$@")
eval set -- "$OPTS"
while :
do
  case "$1" in
    -d | --dry-run )
      dry_run=1
      shift 1
      ;;
    -e | --extra-check )
      extra_check=1
      shift 1
      ;;
    -h | --help)
      help
      exit 0
      ;;
    --)
      shift;
      break
      ;;
    *)
      help
      exit 0
      ;;
  esac
done

if [ $extra_check -ne 0 ]; then
  ##AER
  if [ $(dmesg --since '1 hour ago' | grep 'pcieport.*AER:'|wc -l) -ne 0 ]; then
      msg='WARN: pcieport AER shown in dmesg'
      echo $msg
  fi
  ##NV_ERR_INVALID_STATE
  if [ $(dmesg --since '8 hour ago' | grep NV_ERR_INVALID_STATE.*nv_gpu_ops.c|wc -l) -ne 0 ]; then
      msg='ERROR: NV_ERR_INVALID_STATE shown in dmesg'
      echo $msg
  fi
  ## Hardware Error
  if [ $(dmesg --since '8 hour ago' | grep 'Hardware Error'|wc -l) -ne 0 ]; then
      msg='ERROR: Hardware Error shown in dmesg'
      echo $msg
  fi
  ## DBE
  if [ $(dmesg --since '8 hour ago' | grep 'Xid.*uncorrectable double bit error'|wc -l) -ne 0 ]; then
      msg='ERROR: uncorrectable double bit error shown in dmesg'
      echo $msg
  fi
  ## knvlinkDiscoverPostRxDetLinks
  if [ $(dmesg --since '8 hour ago' | grep 'NVRM: knvlinkDiscoverPostRxDetLinks'|wc -l) -ne 0 ]; then
      msg='ERROR: knvlinkDiscoverPostRxDetLinks error shown in dmesg'
      echo $msg
  fi
  ##NVME
  ret=($(
  for i in $(ls -1 /sys/class/nvme); do
  echo $i=$[$(blockdev --getsz /dev/${i}n1)*512/1000/1000/1000/1000]
  done
  ))
  a=$(echo ${ret[*]}|tr ' ' '\n'|grep nvme.*=7|wc -l)
  b=$(echo ${ret[*]}|tr ' ' '\n'|grep nvme.*=1|wc -l)
  if [ ${#ret[*]} -ne 9 ]; then
    msg='WARN: NVME disk number is not 9'
    echo $msg
  else
    if [ $a -ne 8 ]; then
      msg='WARN: NVME data disk number is not 8'
      echo $msg
    fi
    if [ $b -ne 1 ]; then
      msg='WARN: NVME os disk number is not 1'
      echo $msg
    fi
  fi
  
  ##Enroot disk check
  enroot_runtime_path=$(grep ENROOT_RUNTIME_PATH /etc/enroot/enroot.conf|grep -o /.*/)
  if [ ! -d $enroot_runtime_path ]; then
    enroot_runtime_path=$(df -Th|grep '/dev/md'|awk '{print $NF}'|head -n1)
    if [ "X${enroot_runtime_path}" == "X" ]; then
      enroot_runtime_path=/root
    fi
  fi
  touch $enroot_runtime_path/test &>/dev/null
  ret=$?
  if [ $ret -ne 0 ]; then
    msg="ERROR: Can't write to enroot runtime dir: $enroot_runtime_path"
    echo $msg
  else
    rm -f $enroot_runtime_path/test
  fi

  ##GPU ECC
  ret=($(nvidia-smi --format=csv --query-gpu gpu_bus_id,ecc.errors.uncorrected.aggregate.total|grep -v pci.bus_id|tr ',' ' '|while read bus_id ecc; do [ $ecc -ne 0 ] && echo $bus_id; done))
  if [ ${#ret[*]} -ne 0 ]; then
    msg="WARN: GPU ECC: $(echo ${ret[*]})"
    echo $msg
  fi
fi

## CPU
if [ $(grep processor /proc/cpuinfo|wc -l) -ne 144 ]; then
  msg='ERROR: CPU CORES is not 144'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
cpupower -c all frequency-set -g performance &>/dev/null
if [ $(grep -v performance /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor|wc -l) -ne 0 ]; then
  msg='ERROR: CPU governor is not performance'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
s0=$(cat /sys/devices/system/cpu/cpu{0..71}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{print int(sum/NR/1000)}')
s1=$(cat /sys/devices/system/cpu/cpu{72..143}/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{print int(sum/NR/1000)}')
if [ ${s0} -lt 500 ]; then
  msg='ERROR: CPU socket0 average frequency is abnormal(<500MHz)'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ ${s1} -lt 500 ]; then
  msg='ERROR: CPU socket1 average frequency is abnormal(<500MHz)'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi

## MEM
if [ $(dmidecode -t memory|grep -P '\tSize:'|tr -d '\t'|grep 480|wc -l) -ne 2 ]; then
  msg='ERROR: Memory size is not 2*480GB'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi

## GPU
if [ $(lspci | grep '3D controller' | wc -l) -ne 4 ]; then
  msg='ERROR: GPU number is not 4'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ $(lspci | grep '3D controller' | grep 'rev ff' | wc -l) -gt 0 ]; then
  msg='ERROR: GPU met ref ff issue'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if `nvidia-smi -L` &>/dev/null; then
  msg="ERROR: GPU driver didn't load correctly"
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ $(nvidia-smi nvlink -s|grep '5[0-9].* GB/s'|wc -l) -ne 72 ]; then
  msg='ERROR: 72 GPU NVLINKs are not fully connected'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ $(nvidia-smi --format=csv --query-gpu gpu_bus_id,fabric.status|grep 'GPU requires reset'|wc -l
) -ne 0 ]; then
  msg='ERROR: GPU needs reset to recover the NVLINKs'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi

## IMEX
if [ $(ls -1 /dev/nvidia-caps-imex-channels/|wc -l) -lt 1 ]; then
  msg='ERROR: IMEX channel doesnt exist'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ ! -f /etc/nvidia-imex/nodes_config.cfg ]; then
  msg='ERROR: IMEX /etc/nvidia-imex/nodes_config.cfg doesnt exist. Restart nvidia-imex service'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ "X$(nvidia-imex-ctl -q 2>/dev/null)" != "XREADY" ]; then
  msg='ERROR: IMEX is not active'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi

## IB
if [ $(lspci | grep 'Infiniband controller'|wc -l) -ne 4 ]; then
  msg='ERROR: IB HCA number is not 4'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if [ $(lspci | grep 'Ethernet.*BlueField-3'|wc -l) -ne 4 ]; then
  msg='WARN: BlueField-3 ethernet ports number is not 4'
  echo $msg
  #reason="${reason} ${msg}"
  #global_status=$[global_status+1]
fi
active_hcas=($(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do hca=$(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*)); grep ACTIVE /sys/class/infiniband/${hca}/ports/1/state &>/dev/null && echo ${hca}:1;done))
if [ ${#active_hcas[*]} -ne 4 ]; then
  msg="WARNING: Active HCA number is not 4" # $(echo ${active_hcas[*]}|tr ' ' ',')
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
hcas=($(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*));done))
ret=($(
for dev in ${hcas[*]}; do
  link_downed=$(</sys/class/infiniband/${dev}/ports/1/counters/link_downed)
  symbol_error=$(</sys/class/infiniband/${dev}/ports/1/counters/symbol_error)
  if [[ ${link_downed} -ne 0 || ${symbol_error} -ne 0 ]]; then
    echo ${dev}:link_downed=${link_downed},symbol_error=${symbol_error}
  fi
done
))
if [ ${#ret[*]} -ne 0 ]; then
  echo "WARNING: ${ret[*]}"
fi

## NFS
if `df -Th|grep master:/home` &>/dev/null; then
  msg='ERROR: home not mounted'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi
if `df -Th|grep master:/cm/shared` &>/dev/null; then
  msg='ERROR: cmshared not mounted'
  echo $msg
  reason="${reason} ${msg}"
  global_status=$[global_status+1]
fi

#CUDA Test
if [ $(nvidia-smi topo -p2p n|grep GPU[0-9].*OK|wc -l) -eq 0 ]; then
    msg='ERROR: GPU P2P is disabled'
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
fi
if [ -x /home/cmsupport/workspace/cudatest/foo ]; then
  timeout 3 /home/cmsupport/workspace/cudatest/foo &>/dev/null
  ret=$?
  if [ $ret -ne 0 ]; then
    msg='ERROR: Cannot run even a simple CUDA app'
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
  fi
fi

## Print health check status
if [ ${global_status} -ne 0 ]; then
  echo 'INFO: Health check FAILED'
else
  echo 'INFO: Health check PASSED'
fi

##
#exit ${global_status}
source /etc/profile
module load slurm
if [ ${dry_run} -ne 1 ]; then
  if [ ${global_status} -ne 0 ]; then
    scontrol update nodename=$(hostname) stat=drain reason="${reason}"
  else
    if `scontrol show node $(hostname)|grep State=|grep -i DRAIN &>/dev/null`; then
      scontrol update nodename=$(hostname) stat=undrain
    fi
  fi
fi
