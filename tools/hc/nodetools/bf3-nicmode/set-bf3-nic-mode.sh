#/bin/bash

(
systemctl status rshim.service &>/dev/null || systemctl start rshim.service
lsmod | grep mst_pciconf &>/dev/null || mst start &>/dev/null
mst status -v|grep BlueField3|awk '{print $2}'|while read i; do echo $i $(mlxconfig -d ${i} -e -y set INTERNAL_CPU_OFFLOAD_ENGINE=1 | grep INTERNAL_CPU_OFFLOAD_ENGINE); done
# mst status -v|grep BlueField3|awk '{print $2}'|while read i; do echo $i $(mlxconfig -d ${i} -e query INTERNAL_CPU_OFFLOAD_ENGINE | grep INTERNAL_CPU_OFFLOAD_ENGINE); done
ipmitool power cycle
#
) 2>&1 | tee /tmp/bf3-$(hostname).txt

#for i in *.txt; do echo $i $(grep DISABLED $i|wc -l); done|grep -v -w 4

