#!/bin/bash

NODELIST=$1

pdsh -f 100 -R ssh -w ${NODELIST} <<- 'EOF' | sort &> /tmp/roce_pause.log
for i in $(grep ACTIVE /sys/class/infiniband/*/ports/1/state|cut -f5 -d'/'|grep -v bond); do ifdev=$(ls -1 /sys/class/infiniband/${i}/device/net/); ret=($(mlxlink -d ${i} -c|grep -E 'Effective Physical Errors|Link Down Counter'|awk '{print $NF}')); echo $i,$(ethtool -S $ifdev|grep -E 'rx_prio3_pause:|tx_prio3_pause:|rx_prio3_discards:'|tr -d ' '|paste -s -d ','),link_downed:${ret[1]},effective_error:${ret[0]},roce_adp_retrans:$(</sys/class/infiniband/${i}/ports/1/hw_counters/roce_adp_retrans),np_cnp_sent:$(</sys/class/infiniband/${i}/ports/1/hw_counters/np_cnp_sent),rp_cnp_handled:$(</sys/class/infiniband/${i}/ports/1/hw_counters/rp_cnp_handled); done
EOF
cat /tmp/roce_pause.log | grep ',rx_prio3_pause' |grep -E 'pause:[1-9][^,]*,|roce_adp_retrans:[1-9][^,]*,'|sort -t':' -n -k4

pdsh -f 100 -R ssh -w ${NODELIST} <<- 'EOF'
for i in $(grep ACTIVE /sys/class/infiniband/*/ports/1/state|cut -f5 -d'/'); do ret=$(mlxlink -d ${i} -c|grep Recommendation|cut -f2- -d ':'|grep -v 'No issue was observed'||true); [ "X$ret" != "X" ] && echo $i,$ret || true; done
EOF

pdsh -f 100 -R ssh -w ${NODELIST} <<- 'EOF'
for i in $(grep ACTIVE /sys/class/infiniband/*/ports/1/state|cut -f5 -d'/'); do mlxlink -d ${i} -p 1 -pc &>/dev/null; done
EOF
