#!/bin/bash
#
hosts=(
GB200-POD1-A{03,05,07,09,11,13,15,17}-Node{01..18}
GB200-POD1-B{02,04,06,08,10,12,14,16}-Node{01..18}
GB200-POD2-E{03,05,07,09,11,13,15,17}-Node{01..18}
GB200-POD2-F{02,04,06,08,10,12,14,16}-Node{01..18}
)

pdsh -t 3 -u 3 -R ssh -f 36 -w $(echo ${hosts[*]}|tr ' ' ',') <<< 'uname -r' 2>/dev/null <<- 'EOF' | dshbak -c
#for i in {0,1,4,5}; do echo mlx5_$i; mlxlink -d mlx5_$i  -m | egrep 'State|Recommendation|dBm' ; done 
for i in {enP6p3s0f0np0,enP6p3s0f1np1,enP22p3s0f0np0,enP22p3s0f1np1}; do ip link set $i up ; done 
EOF

