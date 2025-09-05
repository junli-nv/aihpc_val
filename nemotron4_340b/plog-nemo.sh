#!/bin/bash
#
printf "%160s%30s%30s\n" FILENAME "train_step_timing(s)" "tflops_per_sec_per_gpu"
find results/ -name '*[0-9]N-*.txt'| while read i; do
  #ret=($(grep 'iteration 80' $i|awk '{print $(NF-6),$(NF-3)}'))
  ret=($(grep 'iteration 200' $i|awk '{print $(NF-6),$(NF-3)}'))
  if [ ${#ret[*]} -gt 0 ]; then
    printf "%160s%30s%30s\n" ${i##*/} ${ret[0]} ${ret[1]}
  else
    printf "%160s%30s%30s\n" ${i##*/} FAILED 0
  fi  
done
