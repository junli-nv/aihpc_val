#!/bin/bash
#
## Generate host bmc list
#cmsh -c 'category list'|grep dgx-gb200-rack|awk '{print $1}' | while read i
#do
#cmsh -c "device; foreach -c $i (get hostname; interfaces; list bmc)"|grep -E 'GB200|rf0'|paste - -|awk '{print $1,$4}'
#done | sort | tee hosts.conf
cmsh <<- 'EOF' | grep -v PhysicalNode| tee hosts.list
device; foreach -t PhysicalNode ( get hostname; interfaces; list bmc)|grep -E 'GB200-|bmc'|paste - -|awk '{print $1,$4}'
EOF

cmsh <<- 'EOF' | grep -v Switch| tee -a hosts.list
device; foreach -t Switch ( get hostname; interfaces; list bmc)|grep -E 'GB200-|bmc'|paste - -|awk '{print $1,$4}'
EOF

cmsh <<- 'EOF' | grep -v PowerShelf| tee -a hosts.list
device; foreach -t PowerShelf ( get hostname; interfaces; list physical)|grep -E 'GB200-|physical'|paste - -|awk '{print $1,$4}'
EOF
