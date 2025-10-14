#!/bin/bash

plog(){
  jid=$1
  logs=($(ls -1 $(dirname $(sacct -o 'StdOut%1000' -j $jid|grep out))/*${jid}_*.out))
  for i in ${logs[*]}; do
  echo $i
  awk -F'|' '/iteration.*train_step_timing/{print $8}' $i|awk '{print $NF}' \
    | gnuplot -e "set title '$(basename $i|tr '_' '+')'; set term dumb size 300,50; set yrange [0:10]; set ytics 0.5; plot '-' with linespoints"
  done
}

SACCT_FORMAT="User,JobID,Start,End,Elapsed,AllocNodes,WorkDir%30,NodeList%100" sacct -j ${JOBID}

apt install -y gnuplot-nox

logs=(
$(ls -1 *.txt *.out)
)
for i in ${logs[*]}; do
  log=$i
  if [ $(grep iteration.*train_step_timing $log|wc -l) -gt 10 ]; then
    awk -F'|' '/iteration.*train_step_timing/{print $8}' $log|awk '{print $NF}' \
      | gnuplot -e "set title '$(basename $log|tr '_' '+')'; set term dumb size 300,50; set yrange [0:10]; set ytics 0.5; plot '-' with linespoints"
  fi
done
