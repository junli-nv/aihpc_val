#!/bin/bash

extra_check=0
dmesg_hours_to_look_back=8
nvme_disk_expected_count=9
nvme_data_disk_expected_count=8
nvme_data_disk_expected_size_tb=7
nvme_os_disk_expected_count=1
nvme_os_disk_expected_size_tb=1

check_cpu=1
cpu_expected_count=144

check_mem=1
memory_expected_size_gb_per_socket=480

check_gpu=1
gpu_expected_count=4
gpu_expected_memory_size_gb=32
check_nvlink=1
check_imex=1
check_cuda=1

check_ib=1
ib_expected_count=4
bf3_expected_ethernet_count=4

check_spx=0

check_nfs=1

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
topdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  if [ $(dmesg --since "${dmesg_hours_to_look_back} hour ago" | grep 'pcieport.*AER:'|wc -l) -ne 0 ]; then
      msg='WARN: pcieport AER shown in dmesg'
      echo $msg
  fi
  ##NV_ERR_INVALID_STATE
  if [ $(dmesg --since "${dmesg_hours_to_look_back} hour ago" | grep NV_ERR_INVALID_STATE|wc -l) -ne 0 ]; then
      msg='ERROR: NV_ERR_INVALID_STATE shown in dmesg'
      echo $msg
  fi
  ## Hardware Error
  if [ $(dmesg --since "${dmesg_hours_to_look_back} hour ago" | grep 'Hardware Error'|wc -l) -ne 0 ]; then
      msg='ERROR: Hardware Error shown in dmesg'
      echo $msg
  fi
  ## DBE
  if [ $(dmesg --since "${dmesg_hours_to_look_back} hour ago" | grep 'Xid.*uncorrectable double bit error'|wc -l) -ne 0 ]; then
      msg='ERROR: uncorrectable double bit error shown in dmesg'
      echo $msg
  fi
  ## knvlinkDiscoverPostRxDetLinks
  if [ $(dmesg --since "${dmesg_hours_to_look_back} hour ago" | grep 'NVRM: knvlinkDiscoverPostRxDetLinks'|wc -l) -ne 0 ]; then
      msg='ERROR: knvlinkDiscoverPostRxDetLinks error shown in dmesg'
      echo $msg
  fi
  ##NVME
  ret=($(
  for i in $(ls -1 /sys/class/nvme); do
  echo $i=$[$(blockdev --getsz /dev/${i}n[0-9])*512/1000/1000/1000/1000]
  done
  ))
  a=$(echo ${ret[*]}|tr ' ' '\n'|grep nvme.*=${nvme_data_disk_expected_size_tb}|wc -l)
  b=$(echo ${ret[*]}|tr ' ' '\n'|grep nvme.*=${nvme_os_disk_expected_size_tb}|wc -l)
  if [ ${#ret[*]} -ne ${nvme_disk_expected_count} ]; then
    msg="WARN: NVME disk number is not ${nvme_disk_expected_count}"
    echo $msg
  else
    if [ $a -ne ${nvme_data_disk_expected_count} ]; then
      msg="WARN: NVME data disk number is not ${nvme_data_disk_expected_count}"
      echo $msg
    fi
    if [ $b -ne ${nvme_os_disk_expected_count} ]; then
      msg="WARN: NVME os disk number is not ${nvme_os_disk_expected_count}"
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

if [ ${check_cpu} -ne 0 ]; then
  ## CPU
  if [ $(grep processor /proc/cpuinfo|wc -l) -ne ${cpu_expected_count} ]; then
    msg="ERROR: CPU CORES is not ${cpu_expected_count}"
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
  s0=$(cat /sys/devices/system/node/node0/cpu*/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{print int(sum/NR/1000)}')
  s1=$(cat /sys/devices/system/node/node1/cpu*/cpufreq/cpuinfo_cur_freq|awk 'BEGIN{sum=0}{sum+=$1}END{print int(sum/NR/1000)}')
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
fi

if [ ${check_mem} -ne 0 ]; then
  ## MEM
  if [ $(dmidecode -t memory|grep -P '\tSize:'|tr -d '\t'|grep ${memory_expected_size_gb_per_socket}|wc -l) -ne 2 ]; then
    msg="ERROR: Memory size is not 2*${memory_expected_size_gb_per_socket}GB"
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
  fi
fi

if [ ${check_gpu} -ne 0 ]; then
  ## GPU
  if [ $(lspci | grep '3D controller' | wc -l) -ne ${gpu_expected_count} ]; then
    msg="ERROR: GPU number is not ${gpu_expected_count}"
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
fi

if [ ${check_nvlink} -ne 0 ]; then
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
  if [ $(nvidia-smi topo -p2p n|grep GPU[0-9].*OK|wc -l) -eq 0 ]; then
    msg='ERROR: GPU P2P is disabled'
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
  fi
fi

if [ ${check_imex} -ne 0 ]; then
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
fi

if [ ${check_ib} -ne 0 ]; then
  ## IB
  if [ $(lspci | grep 'Infiniband controller'|wc -l) -ne ${ib_expected_count} ]; then
    msg="ERROR: IB HCA number is not ${ib_expected_count}"
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
  fi
  if [ $(lspci | grep 'Ethernet.*BlueField-3'|wc -l) -ne ${bf3_expected_ethernet_count} ]; then
    msg="WARN: BlueField-3 ethernet ports number is not ${bf3_expected_ethernet_count}"
    echo $msg
    #reason="${reason} ${msg}"
    #global_status=$[global_status+1]
  fi
  active_hcas=($(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do hca=$(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*) 2>/dev/null); [ ! -z $hca ] && grep ACTIVE /sys/class/infiniband/${hca}/ports/1/state &>/  dev/null && echo ${hca}:1;done))
  if [ ${#active_hcas[*]} -ne ${ib_expected_count} ]; then
    msg="WARNING: Active HCA number is not ${ib_expected_count}" # $(echo ${active_hcas[*]}|tr ' ' ',')
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
  fi
  hcas=($(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*) 2>/dev/null);done))
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
  ret=($(
  for dev in ${hcas[*]}; do
    link_w=($(mlxlink -d ${dev} --port_type pcie | grep Width | awk '{print $(NF-1)}'))
    if [[ ${link_w[0]} != "16X" ]]; then
      echo "${dev}[LinkWidth]:${link_w[0]}"
    fi
  done
  ))
  if [ ${#ret[*]} -ne 0 ]; then
    echo "WARNING: ${ret[*]}"
  fi
fi

if [ ${check_spx} -ne 0 ]; then
## SPX
  ret=($(
  for dev in /sys/class/infiniband/mlx5_*; do
    roce_adp_retrans=$(</sys/class/infiniband/$(basename ${dev})/ports/1/hw_counters/roce_adp_retrans)
    if [[ ${roce_adp_retrans} -ne 0 ]]; then
      echo $(basename ${dev}):roce_adp_retrans=${roce_adp_retrans}
    fi
  done
  ))
  if [ ${#ret[*]} -ne 0 ]; then
    msg="WARNING: SPX RoCE ADP retransmissions: ${ret[*]}"
    echo $msg
    reason="${reason} ${msg}"
    global_status=$[global_status+1]
  fi
fi

if [ ${check_nfs} -ne 0 ]; then
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
fi

if [ ${check_cuda} -ne 0 ]; then
  #CUDA Test
  if [ -x ${topdir}/cudatest/foo ]; then
    timeout 3 ${topdir}/cudatest/foo &>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
      msg='ERROR: Cannot run even a simple CUDA app'
      echo $msg
      reason="${reason} ${msg}"
      global_status=$[global_status+1]
    fi
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
