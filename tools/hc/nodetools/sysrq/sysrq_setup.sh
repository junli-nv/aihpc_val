#!/bin/bash

## Enable SysRq key
sysctl -w kernel.sysrq=1
echo 8 > /proc/sysrq-trigger

## Trigger sysrq via SOL over IPMI:
# 1. Press Enter+~B+8 to set log level to debug if sysrq-trigger not been set
# 2. Press Enter+~B+m to dump memory information
# 3. Press Enter+~B+0 to set log level back to previous level

## Trigger sysrq via SOL over SSH:
# Replace break signal generated with Enter+~~B, then follow the same steps as above.
