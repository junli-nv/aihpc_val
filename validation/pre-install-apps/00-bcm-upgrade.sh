#!/bin/bash

grep '^[a-z]' /etc/cm-install-release
#date:       Jul 16 2025 09:38AM +0000
#medium:     ISO
#release:    11.25.05
#installer:  baremetal

apt update
apt --yes --assume-yes --allow-unauthenticated -o Dpkg::Options::="--force-confold" upgrade
sudo apt purge -y unattended-upgrades
rm -f /var/log/apt/*
rm -rf /tmp/*
truncate -s 0 /etc/machine-id
truncate -s 0 /root/.bash_history

reboot

