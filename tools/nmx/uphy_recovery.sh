#!/bin/bash

## Enable uphy-recovery on every nvswitch:
nv set fae interface acp1-144 link phy-recovery serdes-eq-mode enable
nv config apply -y
nv config save

## On each compute tray
nvidia-smi -r

## Check on every nvswitch, expect serdes-eq-mode be in enabled status.
seq 1 144|xargs -P 9 -I {} bash -c "(echo {} && nv show fae interface acp{} link phy-recovery)|paste -s -d' '"

