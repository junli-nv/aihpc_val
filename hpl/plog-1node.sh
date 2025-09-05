#!/bin/bash
#
hosts=(
GB200-POD1-A{03,05,07,09,11,13,15,17}-Node{01..18}
GB200-POD1-B{02,04,06,08,10,12,14,16}-Node{01..18}
GB200-POD2-E{03,05,07,09,11,13,15,17}-Node{01..18}
GB200-POD2-F{02,04,06,08,10,12,14,16}-Node{01..18}
)
# echo ${#hosts[*]} ${hosts[*]}

printf "%20s%10s%20s%20s%20s%20s%10s\n" HOSTNAME LOOPS "MAX(TF)" "MIN(TF)" "AVG(TF)" "AVG(TF)perGPU" "VAR(%)"
for i in ${hosts[*]}; do
  ret=($(find results/ -name "*${i}*"|xargs -I {} grep WC {}|awk '{printf("%.2f\n", $(NF-2)/1000)}'|sort -nr))
  if [ ${#ret[*]} -gt 0 ]; then
    avg=($(echo ${ret[*]}|tr ' ' '\n'|awk 'BEGIN{sum=0}{sum+=$1}END{printf("%.2f %.2f\n", sum/NR, sum/NR/4)}'))
    #vari=$(echo "scale=2; 100-${ret[-1]}*100/${ret[0]}"|bc)
    vari=$(echo | awk '{printf("%.2f\n", 100*(1-a/b))}' a=${ret[-1]} b=${ret[0]})
    printf "%20s%10s%20s%20s%20s%20s%10s\n" ${i} ${#ret[*]} ${ret[0]} ${ret[-1]} ${avg[0]} ${avg[1]} ${vari}
  else
    printf "%20s%10s%20s%20s%20s%20s%10s\n" ${i} $(find results/ -name "*${i}*"|xargs -I {} grep hpl-linux-aarch64-gpu/hpl.sh {}|wc -l)+"FAILED" 0 0 0 0 0
  fi
done
