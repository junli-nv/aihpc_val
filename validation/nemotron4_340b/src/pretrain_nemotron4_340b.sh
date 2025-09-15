#!/bin/bash

cat > /usr/local/bin/sbatch <<- 'EOF'
#!/bin/bash
echo "sbatch $@"
EOF
chmod a+x /usr/local/bin/sbatch

mv /opt/NeMo/scripts/performance/recommended_model_configs/model_configs_gb200.csv \
   /opt/NeMo/scripts/performance/recommended_model_configs/model_configs_gb200.csv.ori

if [ $# -ne 1 ]; then
  echo "INFO: Run $0 GPUs[32|64|128|256|...]"
  exit 1
fi
GPUs=$1
if [[ $GPUs%32 -ne 0 ]]; then
  echo "INFO: GPUs need times of 32"
  exit 1
fi
GBS=$[(GPUs/32)*8]

cd /opt/NeMo
export NEMORUN_HOME=${nfs_share_dir}

set -x
python -m scripts.performance.llm.pretrain_nemotron4_340b \
  --account root \
  --partition defq \
  --log_dir ${NEMORUN_HOME} \
  --container_image ${NEMORUN_HOME}/nemo-25.04.rc2.sqsh \
  --nemo_home ${NEMORUN_HOME}/experiments \
  --gpu gb200 \
  --compute_dtype bf16 \
  --num_gpus ${GPUs} \
  -tp 4 \
  -pp 8 \
  -cp 1 \
  -ep 1 \
  -vp 12 \
  -mb 1 \
  -gb ${GBS} \
  --gpus_per_node 4 \
  --max_steps 20000
set +x
