#!/bin/bash
#
reservation_name=xshang_8
target_nodes=$(sinfo -al|grep ${reservation_name}|grep -E '(reserved|allocated) '|awk '{print $NF}'|paste -s -d',')
all_hosts=($(scontrol show hostname ${target_nodes}))
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o CheckHostIP=no"
pdsh -R ssh -w $(echo ${all_hosts[*]}|tr ' ' ',') <<- 'EOF'|dshbak -c
bash /home/cmsupport/workspace/hc/checker.sh
EOF
#
# sinfo -R -o "%120E %12U %19H %6t %N"

