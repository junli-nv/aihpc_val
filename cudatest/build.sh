#!/bin/bash
#
module load shared
module load cuda12.8/toolkit/12.8.1
nvcc foo.cpp -o foo
