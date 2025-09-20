#!/bin/bash

cm-wlm-setup
# Setup (Express)
# Slurm
# Save config & deploy

cm-wlm-setup
# Add Pyxis to Slurm cluster
# Leave Enroot settings untouched

# rm -rf /cm/shared/apps/slurm/statesave/slurm/*

#echo 'SLURMDBD_OPTIONS=-vvv' > /etc/default/slurmdbd
usermod -a -G syslog,root slurm
chmod 775 /run
sed -i.ori -e 's:Type=.*:Type=simple:g' -e 's:\(ExecStart=.*\):\1 -D:g' /lib/systemd/system/slurmdbd.service
systemctl daemon-reload
systemctl restart slurmdbd.service
systemctl status slurmdbd.service
sleep 5
systemctl restart slurmctld.service
systemctl status slurmctld.service
