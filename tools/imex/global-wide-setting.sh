#!/bin/bash

cmsh <<- 'EOF'
category
clone default-ubuntu2404-aarch64 gb200
set softwareimage gb200-image
set bootloader grub
set bootloaderprotocol tftp
bmcsettings
set username root
set password 0penBmc
set extraarguments "-I 17"
..
services
add nvidia-imex
set monitored yes
set autostart yes
set managed yes
commit
EOF

cmsh <<- 'EOF'
configurationoverlay
use slurm-client-gpu
roles
use slurmclient
set imex no
commit
EOF

### Workaround the wrong CUUID collected by BCM. 
cmsh -c 'device; nvdomaininfo'| grep Success|awk '{print $1":"$4}'|sort|uniq|dshbak -c
### Reset the CUUID:
# pdsh -R ssh -w $(echo ${hosts[*]}|tr ' ' ',') <<- 'EOF' | dshbak -c
# systemctl stop cmd; systemctl restart nvidia-dcgm; sleep 10; systemctl start cmd
# EOF

cmsh <<- 'EOF'
category
foreach * (bmcsettings; set extraarguments "-I 17"; commit;)
foreach * (bmcsettings; get extraarguments;)
EOF