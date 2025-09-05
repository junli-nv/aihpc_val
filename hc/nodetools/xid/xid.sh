#!/bin/bash
#
#
hostname &>/dev/null || exit 1

mkdir -p /home/cmsupport/workspace/hc/nodetools/xid/logs
for i in /var/log/dmesg*
do
  if [ "${i##*.}" == "gz" ]; then
    cmd="zcat"
  else
    cmd="cat"
  fi
  dmesg|grep Xid
  eval $cmd $i|grep Xid
done &> /home/cmsupport/workspace/hc/nodetools/xid/logs/$(hostname).xid.txt

exit 0
