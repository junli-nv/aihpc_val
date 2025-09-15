#!/bin/bash

ulimit -s 8192
#case ${OMPI_COMM_WORLD_LOCAL_RANK} in
#  0) UCX_NET_DEVICES="mlx5_0:1"; ;;
#  1) UCX_NET_DEVICES="mlx5_1:1"; ;;
#  2) UCX_NET_DEVICES="mlx5_4:1"; ;;
#  3) UCX_NET_DEVICES="mlx5_5:1"; ;;
#esac
#case ${OMPI_COMM_WORLD_LOCAL_RANK} in
#  0|1) UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1"; ;;
#  2|3) UCX_NET_DEVICES="mlx5_4:1,mlx5_5:1"; ;;
#esac
#export UCX_NET_DEVICE
export UCX_NET_DEVICES=$(lspci -D|grep 'Infiniband controller'|awk '{print $1}'|while read i; do hca=$(basename $(ls -l /sys/class/infiniband|grep -o ${i}.*)); grep ACTIVE /sys/class/infiniband/${hca}/ports/1/state &>/dev/null && echo ${hca}:1;done|paste -s -d',')
export OMPI_MCA_btl_openib_if_include=${UCX_NET_DEVICES}
export NCCL_IB_HCA=${UCX_NET_DEVICES}
export CUDA_DEVICE_ORDER=PCI_BUS_ID

cmd="numactl -l $@"
echo "HOST=$(hostname), RANK=${OMPI_COMM_WORLD_RANK}, LOCAL_RANK=${OMPI_COMM_WORLD_LOCAL_RANK}, CORES=$(taskset -pc $$|awk '{print $NF}'), NIC=${UCX_NET_DEVICES}, CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}, CMD=${cmd}"
eval ${cmd}

