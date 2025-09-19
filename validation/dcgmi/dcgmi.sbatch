#!/bin/bash
#SBATCH -p defq
#SBATCH --exclusive
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=36
#SBATCH --gpus-per-node=4
#SBATCH -N 1

if [ "X${LEVEL}" == "XX" ]; then
  LEVEL=3
fi
echo "INFO: DCGMI LEVEL=${LEVEL}"

## Important: Kill processes using GPU resources in advance!!!
pkill -9 dcgmi &>/dev/null
while :
do
  ret=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits | wc -l)
  if [ ${ret} -eq 0 ]; then
    break
  else
    sudo kill -9 $(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits) &>/dev/null
    sleep 5
  fi
done

start=$(date +%s)
if [ "X${LEVEL}X" == "Xp30mX" ]; then
  ret=$(nvidia-smi --format=csv --query-gpu power.max_limit|grep -v power.max_limit|awk '{print int($1)}'|sort -nr|head -n1)
  set -x
  dcgmi diag -r targeted_power -p "targeted_power.target_power=${ret};targeted_power.test_duration=1800"
  set +x
elif [ "X${LEVEL}X" == "Xp2hX" ]; then
  ret=$(nvidia-smi --format=csv --query-gpu power.max_limit|grep -v power.max_limit|awk '{print int($1)}'|sort -nr|head -n1)
  set -x
  dcgmi diag -r targeted_power -p "targeted_power.target_power=${ret};targeted_power.test_duration=7200"
  set +x
else
  set -x
  dcgmi diag -r $LEVEL #-j
  set +x
fi
end=$(date +%s)
echo "INFO: test costs $[end-start] secs"
