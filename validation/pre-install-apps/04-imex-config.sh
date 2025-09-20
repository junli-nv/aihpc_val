#!/bin/bash

image_name=gb200-image

## Collect compute trays' info
cmsh -c 'device; list -f type,hostname:40,category:40,ip:40 -t PhysicalNode' \
  |grep PhysicalNode|grep -v node001|sort -k2|tee /cm/images/${image_name}/etc/nvidia-imex/compute_trays.txt

## Disable global IMEX and per job IMEX
awk '{print $3}' /cm/images/${image_name}/etc/nvidia-imex/compute_trays.txt|sort|uniq|while read i
do
  echo $i
  cmsh -c "category; use $i; services; remove nvidia-imex; commit; list"
done
cmsh -c "configurationoverlay; use slurm-client-gpu; roles; use slurmclient; set imex no; commit"

pdsh -t 3 -u 3 -R ssh -f 36 -w $(awk '{print $2}' /cm/images/${image_name}/etc/nvidia-imex/compute_trays.txt|paste -s -d',') <<- 'EOF'
systemctl stop cmd; systemctl restart nvidia-dcgm; sleep 10; systemctl start cmd
EOF

## Update gb200 image to set the imex along with os boot
cm-chroot-sw-img /cm/images/${image_name} <<- '__END__'
cat > /etc/nvidia-imex/gen_node_config.sh <<- 'EOF'
#!/bin/bash
grep $(hostname|cut -c1-$[$(hostname|wc -c)-3]) /etc/nvidia-imex/compute_trays.txt|awk '{print $NF}' 2>/dev/null > /etc/nvidia-imex/nodes_config.cfg
EOF

cat > /usr/lib/systemd/system/nvidia-imex.service <<- 'EOF'
[Unit]
Description=NVIDIA IMEX service
After=network-online.target
Requires=network-online.target

[Service]
Environment="KRB5_CLIENT_KTNAME=/etc/krb5.keytab"
User=root
PrivateTmp=false
Type=forking
TimeoutStartSec=infinity

ExecStartPre=-/usr/bin/bash /etc/nvidia-imex/gen_node_config.sh
ExecStartPre=-/usr/bin/sleep 2
ExecStart=/usr/bin/nvidia-imex -c /etc/nvidia-imex/config.cfg

LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvidia-imex.service
__END__

awk '{print $3}' /cm/images/${image_name}/etc/nvidia-imex/compute_trays.txt|sort|uniq|while read i
do
  echo $i
  cmsh -c "category; use $i; services; add nvidia-imex; set monitored yes; set autostart yes; set managed no; commit; list"
done

