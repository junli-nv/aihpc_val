
#!/bin/bash

## Generate host bmc list
cmsh -c 'category list'|grep dgx-gb200-rack|awk '{print $1}' | while read i
do
cmsh -c "device; foreach -c $i (get hostname; interfaces; list bmc)"|grep -E 'GB200|rf0'|paste - -|awk '{print $1,$4}'
done | sort | tee host-bmc.txt

### Configure confluent
docker rm -f confluent
docker run -d -ti --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v /etc/ssh:/etc/ssh:ro \
  -v /root/.ssh:/root/.ssh:ro \
  -v /etc/hosts:/etc/hosts:ro \
  -v /etc/genders:/etc/genders:ro \
  --cgroupns=host \
  --hostname confluent \
  --name confluent \
  confluent /usr/sbin/init
sleep 5
docker exec confluent systemctl start confluent
sleep 3
docker exec confluent systemctl status confluent

docker cp /home/junli/confluent/host-bmc.txt confluent:/root/

### Configure
docker exec -ti confluent /bin/bash
nodegroupattrib everything console.logging=full console.method=ipmi
nodegroupattrib everything discovery.passwordrules="expiration=no,loginfailures=no,complexity=no,reuse=no"

nodegroupattrib everything -p bmcuser bmcpass #U:root P:0penBmc

## Define nodes in confluent. host-bmc.txt be copied from BMC head node
cat /root/host-bmc.txt | while read hostname ip
do
  noderemove ${hostname} &>/dev/null
  nodedefine ${hostname}
  nodeattrib ${hostname} hardwaremanagement.manager=${ip} id.uuid=$(uuidgen)
done
