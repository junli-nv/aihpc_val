#!/bin/bash

for i in *.txt; do
printf "%100s%20s\n" $i $(grep 17179869184.*float $i|awk '{print $8}')
done

for i in *.txt; do echo $i $(grep 17179869184.*float $i); done|awk '{if($9==""){print 0}else{print $9}}'| gnuplot -e "set term dumb size 300,50; set yrange [0:950]; set ytics 50; set xtics 1; plot '-' with linespoints"

