#!/bin/bash
#
node_prefix="gb200"
sw_prefix="nvsw"
ps_prefix="ps"

cmsh <<- EOF | grep -v PhysicalNode| tee hosts.list
device; foreach -t PhysicalNode ( get hostname; interfaces; list bmc)|grep -E "${node_prefix}-|bmc"|paste - -|awk '{print \$1,\$4}'
EOF

cmsh <<- EOF | grep -v Switch| tee -a hosts.list
device; foreach -t Switch ( get hostname; interfaces; list bmc)|grep -E "${sw_prefix}-|bmc"|paste - -|awk '{print \$1,\$4}'
EOF

cmsh <<- EOF | grep -v PowerShelf| tee -a hosts.list
device; foreach -t PowerShelf ( get hostname; interfaces; list bmc)|grep -E "${ps_prefix}-|bmc"|paste - -|awk '{print \$1,\$4}'
EOF
