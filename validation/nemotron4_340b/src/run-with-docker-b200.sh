#!/bin/bash

#0. Download container
mkdir -p $HOME/.docker
cat > $HOME/.docker/config.json <<- 'EOF'
{
  "auths": {
    "nvcr.io": {
      "auth": "JG9hdXRodG9rZW46bnZhcGktU0dOcUF2aXc1NHNVb082UXF4OTZUODVDNFdvOTNsVDN1VXA4d0ZZc3JFb1J5WENlQlRzQzZUUExtSkhxelR4dA=="
    }
  }
}
EOF
docker pull nvcr.io/nvidian/nemo:25.04.rc2

##1. Build docker wrapper image
mkdir tmp
cd tmp
cat > entrypoint.sh <<- '__END__'
#!/bin/bash
[ -z ${SSH_PORT} ] && SSH_PORT=2222
/usr/sbin/sshd -D -f /etc/ssh/sshd_config -p ${SSH_PORT}
__END__
chmod 755 entrypoint.sh

cat > wrapper.dockerfile <<- 'EOF'
FROM nvcr.io/nvidian/nemo:25.04.rc2
MAINTAINER JunLi Zhang<junliz@nvidia.com>

ENV DEBIAN_FRONTEND=noninteractive

RUN \
  apt update && \
  apt install -y --no-install-recommends \
    openssh-server openssh-client rdma-core ibverbs-utils infiniband-diags iproute2 iputils-ping \
    build-essential devscripts debhelper fakeroot && \
  apt autoclean -y && \
  apt autoremove -y && \
  rm -rf /var/lib/apt/lists/*

RUN \
  git clone https://github.com/nvidia/nccl.git && \
  cd nccl && \
  git checkout -b v2.28.9-1 tags/v2.28.9-1 && \
  make -j src.build && \
  make pkg.debian.build && \
  apt install ./build/pkg/deb/*.deb && \
  dpkg -l|grep nccl && \
  rm -rf ./build

RUN \
  git clone https://github.com/NVIDIA/nccl-tests.git && \
  cd nccl-tests && \
  make -j MPI=1 NAME_SUFFIX=_mpi MPI_HOME=/usr/local/mpi && \
  rm -f /usr/local/bin/*_perf* && \
  cp build/*_mpi /usr/local/bin/ && \
  rm -rf build/

USER root

RUN \
  echo "root:123456"|chpasswd && \
  mv /etc/ssh/sshd_config /etc/ssh/sshd_config.ori && \
  echo -e 'PermitRootLogin yes\nUsePAM no\nX11Forwarding no\nPrintMotd no\nStrictModes no\nDebianBanner no' > /etc/ssh/sshd_config && \
  mv /etc/ssh/ssh_config /etc/ssh/ssh_config.ori && \
  echo -e 'Host *\nStrictHostKeyChecking no\nUserKnownHostsFile /dev/null\nLogLevel quiet\nCheckHostIP no\n' > /etc/ssh/ssh_config && \
  mkdir -p /var/run/sshd && \
  chmod 600 /var/run/sshd && \
  ssh-keygen -t rsa -f /root/.ssh/id_rsa -N '' && \
  cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys && \
  chmod 600 /root/.ssh/*

COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EOF
docker build -f wrapper.dockerfile -t nvcr.io/nvidian/nemo:25.04.rc2-m2 .
docker save nvcr.io/nvidian/nemo:25.04.rc2-m2 | pigz -c > nemo_25.04.rc2-m2.tar.gz

##2. Dispatch wrapper image to nodes
docker load -i nemo_25.04.rc2-m2.tar.gz
##3. Start container on nodes
docker rm -f test 
#--rm --entrypoint /bin/bash \
docker run -it --shm-size 32g  --ipc=host --network=host \
-d \
--privileged \
--device=/dev/infiniband/uverbs0 --device=/dev/infiniband/rdma_cm \
--ulimit memlock=-1 \
--ulimit stack=-1 \
--gpus all \
--workdir /workspace \
--name test \
-e TERM=xterm \
-e SSH_PORT=2222 \
nvcr.io/nvidian/nemo:25.04.rc2-m2

docker ps -a

##4. Run NCCL in the container on one node
docker exec -ti test /bin/bash

md5sum /root/.ssh/*

hosts=(bcm01-dgx-05 bcm01-dgx-06)

mpirun --allow-run-as-root \
  --mca plm_rsh_args "-p ${SSH_PORT}" \
  --mca pml ucx \
  -H $(for i in ${hosts[*]}; do echo ${i}:1; done|paste -s -d ',') \
  -np 2 \
  hostname

ibv_devinfo|grep -e hca_id -e link_layer -e state|paste - - -

export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
export OMPI_MCA_plm_rsh_args="-p ${SSH_PORT}"
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --bind-to none \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
\
  --mca btl_tcp_if_include bond0 \
  --mca oob_tcp_if_include bond0 \
  -x NCCL_SOCKET_IFNAME=bond0 \
\
  -x UCX_TLS=rc \
  -x UCX_NET_DEVICES="mlx5_7:1,mlx5_8:1,mlx5_9:1,mlx5_11:1" \
  -x NCCL_DEBUG=INFO \
  -x NCCL_IB_HCA="=mlx5_7,mlx5_8,mlx5_9,mlx5_11"  \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:8; done|paste -s -d ',') \
  -np 16 \
  all_reduce_perf_mpi -b 8 -f 2 -g 1 -e 16G
  #/bin/bash -c 'numactl --show $$'

##5. Run nemo training job in the container on multi-nodes
cat > /usr/local/bin/sbatch <<- 'EOF'
#!/bin/bash
echo "sbatch $@"
EOF
chmod a+x /usr/local/bin/sbatch
cd /opt/NeMo
export OPENBLAS_NUM_THREADS=1
export NEMORUN_HOME=/tmp/test
python -m scripts.performance.llm.pretrain_nemotron4_15b \
  --account root \
  --partition defq \
  --log_dir ${NEMORUN_HOME} \
  --gpu b200 \
  --container_image nvcr.io/nvidian/nemo:25.04.rc2-m2 \
  --compute_dtype bf16 \
  --num_gpus 16 \
  --gpus_per_node 8 \
  -tp 1 \
  -pp 1 \
  -cp 1 \
  -ep 1 \
  -mb 2 \
  -gb 64 \
  --max_steps 200

find /tmp/test -name '*_fn_or_script'

CASE=/tmp/pretrain_nemotron4_15b_bf16_2nodes_tp1_pp1_cp1_vp1_2mbs_64gbs_fn_or_script
ssh -p 2222 ${hosts[1]} "cat > ${CASE}" < ${CASE}

ssh -p 2222 ${hosts[0]} md5sum ${CASE}
ssh -p 2222 ${hosts[1]} md5sum ${CASE}

export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
export OMPI_MCA_plm_rsh_args="-p ${SSH_PORT}"
mpirun --allow-run-as-root \
  --mca pml ucx --mca coll ^hcoll --mca btl ^openib,smcuda \
  --bind-to none \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
\
  --mca btl_tcp_if_include bond0 \
  --mca oob_tcp_if_include bond0 \
  -x NCCL_SOCKET_IFNAME=bond0 \
\
  -x UCX_TLS=rc \
  -x UCX_NET_DEVICES="mlx5_7:1,mlx5_8:1,mlx5_9:1,mlx5_11:1" \
  -x NCCL_DEBUG=INFO \
  -x NCCL_IB_HCA="=mlx5_7,mlx5_8,mlx5_9,mlx5_11"  \
\
  -x TORCH_NCCL_AVOID_RECORD_STREAMS=1 \
  -x TRANSFORMERS_OFFLINE=1 \
  -x TOKENIZERS_PARALLELISM=False \
  -x NCCL_NVLS_ENABLE=0 \
  -x NVTE_FLASH_ATTN=1 \
  -x NVTE_FUSED_ATTN=1 \
  -x NEMO_LOG_MEMORY_USAGE=1 \
  -x NEMORUN_HOME=$PWD \
  -x NEMO_HOME=$PWD \
  -x CUDA_DEVICE_MAX_CONNECTIONS=32 \
  -x NVTE_FWD_LAYERNORM_SM_MARGIN=16 \
  -x NVTE_BWD_LAYERNORM_SM_MARGIN=16 \
  -x NCCL_P2P_NET_CHUNKSIZE=2097152 \
\
  -H $(for i in ${hosts[*]}; do echo ${i}:8; done|paste -s -d ',') \
  -np 16 \
  python -m nemo_run.core.runners.fdl_runner -n $(basename ${CASE}|sed -e 's:_fn_or_script::g') ${CASE} 2>&1 | tee log.txt

##6. clean work
docker rm -f test

