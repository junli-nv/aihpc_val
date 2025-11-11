#!/bin/bash
file=$1
echo $file $(grep NODELIST ${file})
cat ${file}|awk '/Collective test starting/,/Collective test concluded/{print $0}'|awk '/float/{print $8}' \
    | gnuplot -e "set term dumb size 300,50; set yrange [0:51]; set ytics 1; set xrange [0:32]; set xtics 1; set key off; set ytics nomirror; set y2range [0:51]; set y2tics 1; plot '-' with linespoints" 

#    | gnuplot -e "set term dumb size 300,50; set yrange [0:51]; set ytics 1; set xrange [0:32]; set xtics 1; set grid; set key off; plot '-' with linespoints" 
