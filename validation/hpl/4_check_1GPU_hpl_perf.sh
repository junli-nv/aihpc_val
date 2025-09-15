#!/bin/bash

for i in  *-1GPU-*; do
  echo $(echo $i|cut -c10-34) $(grep WC $i|awk '{print $7/1000}')
done