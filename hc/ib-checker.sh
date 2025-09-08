#!/bin/bash
#
hosts=(
GB200-POD1-A{03,05,07,09,11,13,15,17}-Node{01..18}
GB200-POD1-B{02,04,06,08,10,12,14,16}-Node{01..18}
GB200-POD2-E{03,05,07,09,11,13,15,17}-Node{01..18}
GB200-POD2-F{02,04,06,08,10,12,14,16}-Node{01..18}
)

pdsh -t 3 -u 3 -R ssh -f 36 -w $(echo ${hosts[*]}|tr ' ' ',') <<< 'uname -r' 2>/dev/null <<- 'EOF' | dshbak -c
#ibstatus|grep -E 'Infiniband|state:'|paste - - -|grep -E 'mlx5_0|mlx5_1|mlx5_4|mlx5_5'|grep -v ACTIVE||true
for i in $(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do echo $(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*));done); do echo ${i}:$(mlxlink -d $i|awk -F':' '/State/{print $NF}'); done | grep -v 'Active' | paste -s -d','
EOF
