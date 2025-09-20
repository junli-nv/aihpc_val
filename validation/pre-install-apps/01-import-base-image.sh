
#################################  X86 BCM head node import arm image

## Prepare for the base image. Can be got from BCM iso
cd /root
mount images/bcm-11.0-ubuntu2404-aarch64-11.25.05.iso /mnt/
cp /mnt/data/UBUNTU2404.tar.gz .

mkdir tmp
cd tmp
tar -xzvf ../UBUNTU2404.tar.gz

## Remove command-not-found, fixing the slow apt update issue, time from 4min to 2min
export QEMU_CPU=max,pauth-impdef=on
chroot .
rm -rf /var/lib/command-not-found /var/cache/swcatalog
apt purge -y command-not-found appstream update-notifier-common
dpkg -l|grep -E 'command-not-found|appstream|update-notifier-common'
exit
tar --numeric-owner -cvf /root/UBUNTU2404-new.tar.gz -I pigz .

## Check packages be installed in image match with the ones on BCM head node, make sure the following two are match each other
grep slurm /cm/local/apps/cluster-tools/config/UBUNTU2404-cm-extrapackages.xml
dpkg -l|grep slurm
# Make sure there is no *-nightly package
grep -E 'cm-config-apt|libglapi' /cm/local/apps/cluster-tools/config/UBUNTU2404-*.xml

## Import image
export QEMU_CPU=max,pauth-impdef=on
time cm-image create all --arch aarch64 --distro ubuntu2404 --source /root/UBUNTU2404-new.tar.gz \
  -j $(grep nvidia /cm/local/apps/cluster-tools/config/UBUNTU2404-*.xml|grep -- -570|awk -F'"' '{print $4}'|sort|uniq|paste -s -d','),nvidia-persistenced,nvidia-modprobe,nvidia-settings,libglapi-mesa \
  -x cm-config-apt-cuda

## Monitor the import progress

#terminal 1
watch -n 1 'ps -ef|grep local'

#terminal 2
tail -f /var/log/cm-image*.log

#terminal 3
tail -f /cm/images/default-image-ubuntu2404-aarch64/var/log/apt/term.log

tail -f /cm/node-installer-ubuntu2404-aarch64/var/log/apt/term.log

mkdir -p /cm/images/default-image-ubuntu2404-aarch64/dev/{pts,shm}
