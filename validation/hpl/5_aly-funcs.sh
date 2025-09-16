plog-1node-all(){
[ $# -eq 0 ] && logdir=./ || logdir=$1
hosts=(
$(sinfo -N|awk '{print $1}'|grep -v NODELIST|sort|uniq)
)
printf "%20s%10s%20s%20s%20s%20s%10s\n" HOSTNAME LOOPS "MAX(TF)" "MIN(TF)" "AVG(TF)" "AVG(TF)perGPU" "VAR(%)"
for i in ${hosts[*]}; do
  ret=($(find ${logdir}/ -maxdepth 1 -name "*${i}*"|xargs -I {} grep WC {}|awk '{printf("%.2f\n", $(NF-2)/1000)}'|sort -nr))
  if [ ${#ret[*]} -gt 0 ]; then
    avg=($(echo ${ret[*]}|tr ' ' '\n'|awk 'BEGIN{sum=0}{sum+=$1}END{printf("%.2f %.2f\n", sum/NR, sum/NR/4)}'))
    vari=$(echo | awk '{printf("%.2f\n", 100*(1-a/b))}' a=${ret[-1]} b=${ret[0]})
    printf "%20s%10s%20s%20s%20s%20s%10s\n" ${i} ${#ret[*]} ${ret[0]} ${ret[-1]} ${avg[0]} ${avg[1]} ${vari}
  else
    printf "%20s%10s%20s%20s%20s%20s%10s\n" ${i} $(find ${logdir} -maxdepth 1 -name "*${i}*"|xargs -I {} grep 'HPLinpack 2.1' {}|wc -l)+"FAILED" 0 0 0 0 0
  fi
done
}

plog-1node(){
[ $# -eq 0 ] && logdir=./ || logdir=$1
hosts=(
$(ls -1 ${logdir}/*-1N-*.txt|grep -o -- -1N-.*|cut -c5-29|sort|uniq)
)
printf "%20s%10s%20s%20s%20s%20s%10s\n" HOSTNAME LOOPS "MAX(TF)" "MIN(TF)" "AVG(TF)" "AVG(TF)perGPU" "VAR(%)"
for i in ${hosts[*]}; do
  ret=($(find ${logdir}/ -maxdepth 1 -name "*${i}*"|xargs -I {} grep WC {}|awk '{printf("%.2f\n", $(NF-2)/1000)}'|sort -nr))
  if [ ${#ret[*]} -gt 0 ]; then
    avg=($(echo ${ret[*]}|tr ' ' '\n'|awk 'BEGIN{sum=0}{sum+=$1}END{printf("%.2f %.2f\n", sum/NR, sum/NR/4)}'))
    vari=$(echo | awk '{printf("%.2f\n", 100*(1-a/b))}' a=${ret[-1]} b=${ret[0]})
    printf "%20s%10s%20s%20s%20s%20s%10s\n" ${i} ${#ret[*]} ${ret[0]} ${ret[-1]} ${avg[0]} ${avg[1]} ${vari}
  else
    printf "%20s%10s%20s%20s%20s%20s%10s\n" ${i} $(find ${logdir} -maxdepth 1 -name "*${i}*"|xargs -I {} grep 'HPLinpack 2.1' {}|wc -l)+"FAILED" 0 0 0 0 0
  fi
done
}

plog-1rack(){
[ $# -eq 0 ] && logdir=./ || logdir=$1
racks=(
$(ls -1 ${logdir}/*-1Rack-*.txt|grep -o -- -1Rack-.*|cut -c8-10|sort|uniq)
)
printf "%20s%10s%20s%20s%20s%20s%20s\n" Rack "TotalRun" "SucessRun" "MAX(TF)perGPU" "MIN(TF)perGPU" "AVG(TF)perGPU" "VAR(%)perGPU"
for i in ${racks[*]}; do
  ret=($(find ${logdir}/ -maxdepth 1 -name '*-8N-*' -o -name '*-16N-*' -o -name '*-18N-*' | grep -- -${i}- | xargs -I {} grep WC {}|tr -d '\)'|awk '{printf("%.2f\n", $NF/1000)}'|sort -nr))
  ret2=$(find ${logdir}/ -maxdepth 1 -name '*-18N-*' | grep -- -${i}- | wc -l)
  if [ ${#ret[*]} -gt 0 ]; then
    avg=$(echo ${ret[*]}|tr ' ' '\n'|awk 'BEGIN{sum=0}{sum+=$1}END{printf("%.2f\n", sum/NR)}')
    #vari=$(echo "scale=2; 100-${ret[-1]}*100/${ret[0]}"|bc)
    vari=$(echo | awk '{printf("%.2f\n", 100*(1-a/b))}' a=${ret[-1]} b=${ret[0]})
    printf "%20s%10s%20s%20s%20s%20s%20s\n" ${i} $(find ${logdir}/ -maxdepth 1 -name '*-8N-*' -o -name '*-16N-*' -o -name '*-18N-*' | grep -- -${i}- | wc -l) ${#ret[*]} ${ret[0]} ${ret[-1]} ${avg} ${vari}
  else
    printf "%20s%10s%20s%20s%20s%20s%20s\n" ${i} $(find ${logdir}/ -maxdepth 1 -name '*-8N-*' -o -name '*-16N-*' -o -name '*-18N-*' | grep -- -${i}- | wc -l)+"FAILED" ${#ret[*]} 0 0 0 0
  fi
done
}

plog-xRack(){
[ $# -eq 0 ] && logdir=./ || logdir=$1
printf "%10s%10s%10s%10s%10s%10s%20s%20s %-160s\n" "Nodes#" "N" "NB" "P" "Q" "Time(s)" "Perf(TF)" "PerGPU(TF)" FILENAME
find ${logdir} -maxdepth 1 -name '*Rack*.txt' | while read i; do
  #ret=($(grep WC $i|tr -d ')'|awk '{print $4*$5/4, $7/1000, $NF/1000}'))
  ret=($(grep WC $i|tr -d ')'|awk '{print $4*$5/4, $2, $3, $4, $5, $6, $7/1000, $NF/1000}'))
  if [ ${#ret[*]} -gt 0 ]; then
    printf "%10s%10s%10s%10s%10s%10s%20s%20s %-160s\n" ${ret[0]} ${ret[1]} ${ret[2]} ${ret[3]} ${ret[4]} ${ret[5]} ${ret[6]} ${ret[7]} ${i##*/}
  else
    ret=($(awk '/The following parameter values will be used:/,/The matrix A is randomly generated for each test/{print $0}' $i|grep -E '^(N |NB |P |Q ).*:'|awk '{print $NF}'))
    printf "%10s%10s%10s%10s%10s%10s%20s%20s %-160s\n" $[${ret[2]}*${ret[3]}/4] ${ret[0]} ${ret[1]} ${ret[2]} ${ret[3]} NA FAILED NA ${i##*/}
  fi
done | sort -n
}
