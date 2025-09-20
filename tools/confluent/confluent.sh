#!/bin/bash

## Install Docker on x86 BCM head node
apt update
apt install -y docker.io
systemctl enable --now docker

### Build conflunet on x86 BCM head node
cat > confluent.dockerfile <<- 'EOF'
FROM rockylinux:9.3
MAINTAINER JunLi Zhang<junliz@nvidia.com>

RUN \
  echo -e '[lenovo-hpc]\nname=Lenovo packages for HPC\nbaseurl=https://hpc.lenovo.com/yum/latest/el9/x86_64/\nenabled=1\ngpgcheck=0' > /etc/yum.repos.d/lenovo-hpc.repo && \
  yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
  yum update -y && \
  yum install -y lenovo-confluent tftp-server openssh-clients openssl vim-enhanced iproute jq

RUN \
  echo -e '#!/bin/bash\nrm -f /var/run/confluent/pid /run/confluent/pid >& /dev/null\n/opt/confluent/bin/confluent -f' > /bin/runconfluent.sh

RUN \
  yum install -y procps ncurses iputils net-tools \
      pdsh pdsh-rcmd-ssh pdsh-mod-genders pdsh-mod-dshgroup pdsh-mod-netgroup \
      ipmitool

CMD ["/usr/sbin/init"]
EOF
docker build -f confluent.dockerfile -t confluent .

### Configure confluent
docker rm -f confluent
docker run -d -ti --privileged \
  --hostname confluent \
  --name confluent \
  confluent /usr/sbin/init
sleep 5
docker exec confluent systemctl start confluent
sleep 3
docker exec confluent systemctl status confluent

cmsh <<- 'EOF' | grep -v PhysicalNode| tee /home/cmsupport/workspace/host-bmc.txt
device; foreach -t PhysicalNode ( get hostname; interfaces; list bmc)|grep -E 'GB200-|bmc'|paste - -|awk '{print $1,$4}'
EOF
docker cp /home/cmsupport/workspace/host-bmc.txt confluent:/root/

### Configure
docker exec -ti confluent /bin/bash
nodegroupattrib everything console.logging=full console.method=ipmi
nodegroupattrib everything discovery.passwordrules="expiration=no,loginfailures=no,complexity=no,reuse=no"

nodegroupattrib everything -p bmcuser bmcpass #U:admin P:GB200@pbd

## Define nodes in confluent. host-bmc.txt be copied from BMC head node
nodelist | while read i; do noderemove $i; done
cat /root/host-bmc.txt | while read hostname ip
do
  noderemove ${hostname} &>/dev/null
  nodedefine ${hostname}
  nodeattrib ${hostname} hardwaremanagement.manager=${ip} id.uuid=$(uuidgen)
done

## Query GB200 nodes status
docker exec -ti confluent /bin/bash

nodepower GB200-POD1-A03-Node[01-18] status

nodehealth GB200-POD1-A03-Node[01-18]

nodesensors GB200-POD1-A03-Node[01-18] -c fans

nodesensors GB200-POD1-A03-Node[01-18] -c power

nodesensors GB200-POD1-A03-Node[01-18] -c temp

nodeeventlog GB200-POD1-A03-Node[01-18]

nodeboot GB200-POD1-B10-Node09 network

nodeconsole GB200-POD1-B10-Node09 #Quit: ctrl+e -> c -> . 


