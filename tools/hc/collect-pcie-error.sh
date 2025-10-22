#!/bin/bash
#
#
for i in mlx5_0 mlx5_1 mlx5_4 mlx5_5; do
  mlxlink -d $i --port_type pcie --depth 0 --pcie_index 0 --node 0 -c -e &> /home/cmsupport/workspace/hc/logs/$(hostname)-$i.txt
done
