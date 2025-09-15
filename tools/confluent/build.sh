#!/bin/bash
## Install squid on BCM head node(172.16.12.79) and allow NMX to use
apt install -y squid
sed -i.ori \
  -e 's:http_access allow localhost:http_access allow all:g' \
/etc/squid/squid.conf
systemctl restart squid

## Install Docker on NMX x86 node(172.16.21.105)
sshpass -p nvis@123 ssh nvis@172.16.21.105 
export http_proxy=http://172.16.12.79:3128
export https_proxy=http://172.16.12.79:3128
apt update
apt install -y docker.io
cat > /etc/docker/daemon.json <<- EOF
{
  "proxies": {
    "http-proxy": "http://172.16.12.79:3128",
    "https-proxy": "http://172.16.12.79:3128",
    "no-proxy": "*.cluster,127.0.0.0/8"
  }
}
EOF
systemctl restart docker
docker info|grep -i proxy
docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${http_proxy} -f confluent.dockerfile -t confluent .