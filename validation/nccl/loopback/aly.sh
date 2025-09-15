#!/bin/bash
#
cd ./results
for i in *.txt; do
  ret=$(grep 17179869184.*float $i|awk '{print $8}')
  if [ -z ${ret} ]; then
    echo $i "FAILED"
  else
    echo $i ${ret}
  fi 
done | sort -k2 -nr | tee perf-loopback.log
