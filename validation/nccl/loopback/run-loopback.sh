#!/bin/bash
#
target_nodes=(
$(sinfo -al|awk '/reserved.*junli_val /{print $NF}'|sed -e 's:],:] :g')
)

pdsh -R ssh -w $(echo ${target_nodes[*]}|tr ' ' ',') <<- 'EOF'|dshbak -c|sed -e 's:],:] :g'
bash /home/cmsupport/workspace/aihpc_val/tools/hc/checker.sh
EOF

good_nodes=(
GB200-DH420-A01-P2-GPU-[01-18] GB200-DH420-A02-P2-GPU-[03-06,09-10,12-18] GB200-DH420-B01-P2-GPU-[01-10,12,14-16,18] GB200-DH420-B02-P2-GPU-[01-02,04-18] GB200-DH420-C01-P2-GPU-[01-15,17-18] GB200-DH420-C02-P2-GPU-[01-14,16-18] GB200-DH420-D01-P2-GPU-[01-18] GB200-DH420-D02-P2-GPU-[01-18] GB200-DH420-E01-P2-GPU-[01-18] GB200-DH420-E02-P2-GPU-[01-18] GB200-DH420-I01-P2-GPU-[01-18] GB200-DH420-I02-P2-GPU-[01-18] GB200-DH420-J01-P2-GPU-[01-18] GB200-DH420-J02-P2-GPU-[01-18] GB200-DH420-K01-P2-GPU-[01-18] GB200-DH420-L01-P2-GPU-[01-18]
)

scontrol show node $(echo ${good_nodes[*]}|tr ' ' ',') |grep -E 'NodeName|State'|paste - -|grep -o State=.*|sort|uniq -c

hosts=($(scontrol show hostname $(echo ${good_nodes[*]}|tr ' ' ',')))
echo ${#hosts[*]} ${hosts[*]}

mkdir -p results
for i in ${hosts[*]}
do
  sbatch --reservation=junli_val \
    -N 1 \
    -w "$i" \
    -t 15:00 \
    --job-name=NCCL_LOOPBACK \
    --output=./results/${USER}-NCCL_LOOPBACK-${i}-1N-%j.txt \
    nccl-loopback.sbatch
done

