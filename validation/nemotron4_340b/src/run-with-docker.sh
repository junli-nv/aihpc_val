#!/bin/bash

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
docker save nvcr.io/nvidian/nemo:25.04.rc2-m2 | pigz -c > /lustre/raplab/client/junliz/workspace/nemo_25.04.rc2-m2.tar.gz

##2. Dispatch wrapper image to nodes
docker load -i /lustre/raplab/client/junliz/workspace/nemo_25.04.rc2-m2.tar.gz
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

mpirun --allow-run-as-root \
  --mca plm_rsh_args "-p ${SSH_PORT}" \
  --mca pml ucx \
  -H L20-GPU-29:1,L20-GPU-30:1 \
  -np 2 \
  hostname

ibv_devinfo

export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
export OMPI_MCA_plm_rsh_args="-p ${SSH_PORT}"
mpirun \
  --mca pml ucx \
  --mca pml_ucx_verbose 10 \
  --bind-to none \
  --display-map --display-topo --report-bindings \
  -x PATH=$PATH \
  -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
  -x UCX_NET_DEVICES="mlx5_0:1,mlx5_1:1,mlx5_2:1,mlx5_3:1" \
  -x NCCL_DEBUG=INFO \
  -x NCCL_IB_HCA="=mlx5_0,mlx5_1,mlx5_2,mlx5_3"  \
  -H L20-GPU-29:4,L20-GPU-30:4 \
  -np 8 \
  all_reduce_perf_mpi -b 8 -f 2 -g 1 -e 16G
  #/bin/bash -c 'numactl --show $$'

##5. clean work
docker rm -f test

