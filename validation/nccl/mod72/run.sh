#!/bin/bash

export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no -o PreferredAuthentications=publickey"

need_validate_nodes=(
$(sinfo -N|grep -E 'GB200-DH420-.*-P2|GB200-DH430-.*-P3'|awk '{print $1}'|paste -s -d ' ')
)

known_bad_nodes=(
##Place holder
NODE_DOESNOT_EXIST
##IB DOWN
#GB200-DH420-B02-P2-GPU-06
#GB200-DH420-D02-P2-GPU-10
)

## Filter the nodes without issues, find out the bad nodes
pdsh -R ssh -w $(scontrol show hostname $(echo ${need_validate_nodes[*]}|tr ' ' ',')|paste -s -d ',') -x $(scontrol show hostname $(echo ${known_bad_nodes[*]}|tr ' ' ',')|paste -s -d ',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
bash /home/cmsupport/workspace/hc/checker.sh || true
EOF

a=(
GB200-DH420-A01-P2-GPU-[01-18] GB200-DH420-A02-P2-GPU-[01-18] GB200-DH420-B01-P2-GPU-[01-18] GB200-DH420-B02-P2-GPU-[01-18] GB200-DH420-C01-P2-GPU-[01-18] GB200-DH420-C02-P2-GPU-[01-18] GB200-DH420-D01-P2-GPU-[01-18] GB200-DH420-D02-P2-GPU-[01-18] GB200-DH420-E01-P2-GPU-[01-18] GB200-DH420-E02-P2-GPU-[01-18] GB200-DH420-I01-P2-GPU-[01-18] GB200-DH420-I02-P2-GPU-[01-18] GB200-DH420-J01-P2-GPU-[01-18] GB200-DH420-J02-P2-GPU-[01-18] GB200-DH420-K01-P2-GPU-[01-18] GB200-DH420-L01-P2-GPU-[01-18]
GB200-DH430-A01-P3-GPU-[01-18] GB200-DH430-A02-P3-GPU-[01-18] GB200-DH430-B01-P3-GPU-[01-18] GB200-DH430-B02-P3-GPU-[01-18] GB200-DH430-C01-P3-GPU-[01-18] GB200-DH430-C02-P3-GPU-[01-18] GB200-DH430-D01-P3-GPU-[01-18] GB200-DH430-D02-P3-GPU-[01-18] GB200-DH430-M01-P3-GPU-[01-18] GB200-DH430-M02-P3-GPU-[01-18] GB200-DH430-N01-P3-GPU-[01-18] GB200-DH430-N02-P3-GPU-[01-18] GB200-DH430-O01-P3-GPU-[01-18] GB200-DH430-O02-P3-GPU-[01-18] GB200-DH430-P01-P3-GPU-[01-18] GB200-DH430-P02-P3-GPU-[01-18]
)
echo ${#a[*]} ${a[*]}

pdsh -R ssh -w $(scontrol show hostname $(echo ${a[*]}|tr ' ' ',')|paste -s -d',') <<- 'EOF'|dshbak -c|sed 's:,GB200: GB200:g'
uname -r
cat /proc/cmdline | tr ' ' '\n'|grep -v -E 'ip=|BOOT' | sort | paste -s -d ' '
EOF

scontrol show node $(echo ${a[*]}|tr ' ' ',') |grep -E 'NodeName|State'|paste - -|grep -o State.*|sort|uniq -c

ret=($(echo ${hosts[*]}|tr ' ' '\n'|cut -c7-15|sort|uniq))
jobname=${#ret[*]}Rack-$(
  echo ${ret[*]}|tr ' ' '\n'|cut -f1 -d'-'|sort|uniq|while read i; do
    echo ${i}-$(echo ${ret[*]}|tr ' ' '\n' | grep $i|cut -f2 -d'-'|paste -s -d'_')
  done|paste -s -d'+'
  )
sbatch --reservation=junli_val \
  -N ${#hosts[*]} \
  -w "$(echo ${hosts[*]}|tr ' ' ',')" \
  -t 15:00 \
  --job-name=${jobname} \
  --output=${USER}-${jobname}-${#hosts[*]}N-%j.txt \
  nccl-mod72.sh
