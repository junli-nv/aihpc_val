#!/bin/bash
mkdir -p /raid/data
dd if=/home/cmsupport/workspace/nemo-25.04.rc2.m2.sqsh of=/raid/data/nemo-25.04.rc2.m2.sqsh bs=1M oflag=direct
md5sum /raid/data/nemo-25.04.rc2.m2.sqsh > /raid/data/nemo-25.04.rc2.m2.sqsh.md5sum
