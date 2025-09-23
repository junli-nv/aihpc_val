#!/bin/bash
for i in {0..3}; do
  echo $i $(dcgmi nvlink -g $i -e 2>&1 |awk -F '|' '/Malformed Packet Erro/,/Effective BER/{print $2, $3}'|paste -s -d' ' | tr -s ' ')
done
