#!/bin/bash
#
logdir=./tmp
#timestamp=$(date +%Y-%m-)
#timestamp=2025-
#timestamp=2025-08-
timestamp=2025-09-
printf "%50s%30s%20s%20s%20s\n" LOGFILE  PS_RUN_PWR_FAULT  Xid149.4  Xid149.a STATUS
for i in $logdir/*.txt; do
   a=$(grep $timestamp $i | grep PS_RUN_PWR_FAULT | wc -l) \
   b=$(grep $timestamp $i | grep 149.*0x004| wc -l) \
   c=$(grep $timestamp $i | grep 149.*0x00a| wc -l)
   if [ $(cat $i|wc -l) -lt 10 ]; then
      status=NA
   else
      [ $[a+b+c] -eq 0 ] && status=PASSED || status=FAILED
   fi
   printf "%50s%30s%20s%20s%20s\n"\
      $i \
      $a \
      $b \
      $c \
      $status
done
