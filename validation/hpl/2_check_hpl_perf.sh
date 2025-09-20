#!/bin/bash

for i in $(ls -1 *.txt); do printf "%100s : %s\n" $i "$(grep WC $i)"; done

