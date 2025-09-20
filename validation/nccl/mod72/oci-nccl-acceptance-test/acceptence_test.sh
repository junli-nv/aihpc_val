#! /bin/bash
python parse_nccl_test_output.py -m
python analyze_results.py -m data_full.pkl -n ib -d 192 -b 50000.0 -t 0.95