#!/bin/bash
# ******************************************************************************
#
#                                --- WARNING ---
#
#   This work contains trade secrets of DataDirect Networks, Inc.  Any
#   unauthorized use or disclosure of the work, or any part thereof, is
#   strictly prohibited.  Copyright in this work is the property of DataDirect.
#   Networks, Inc. All Rights Reserved. In the event of publication, the.
#   following notice shall apply: (C) 2019, DataDirect Networks, Inc.
#
# ******************************************************************************

set -e
set -o pipefail

command="ib_read_bw"

# Kill any lingering processes
pkill -9 $command || true
for i in {0..5} ; do
    if ! ps aux |grep $command |grep -v grep |grep -v "./client.sh" ; then
        break
    fi
    if [ $i -eq 5 ] ; then
        echo "Can't kill $command on "
        exit 1
    fi
    pkill $command || true
    sleep 1
done

# Check IPs passed as arguments (first arg in '' with all the IPs)
if [ $# -gt 2 ] || [ $# -lt 1 ] ; then
    echo "Usage $0 'IP_A IP_B IP_C IP_D' [optional: ib_read_bw/ib_write_bw] # You can get the IP list from the ./server.sh command"
    exit 1
fi

export servers_ips="$1"

if [ $# -eq 2 ] ; then
    echo "Using command: ${2}"
    export command="$2"
fi


logdir="ddn_ib_$command-$(date +%s)"
mkdir $logdir

# Find which interface/card is used
interface=$(ip a |grep ib |grep 'state UP'| awk '{print $2}'|tr -d ':' |head -n 1)
card="$(ibdev2netdev -v |grep ${interface}|grep -E -o "mlx5_[0-9]+")"

# Start all clients against the IPs provided
for rep in {1..10}; do
    d="temp-$(date +%s)"
    mkdir -p ${logdir}/$d
    for i in ${servers_ips[@]}; do
        # You can add --disable_pcie_relaxed there
        # You can also remove -R (rdma)
        $command -d $card --port 18515 -D 30 -R -s 1048576 $i &> ${logdir}/$d/${i}_18515_$d.log  &
        pids+=($!)
    done
    wait "${pids[@]}"
    cat ${logdir}/$d/*_$d.log  | awk '{if (p==1) {p=0;print;total+=$(NF-1)}} /average/ {p=1} END {print "total="total}'
    sleep 1
done


