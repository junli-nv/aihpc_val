#!/bin/bash

# must be root to access extended PCI config space
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: $0 must be run as root"
  exit 1
fi

# Resolve Bug 4696045 - ACS-Disable Script Reports Success Even on Failure:
# Add EXITCODE variable to report the first type of error seen
EXITCODE=0
ERR_DISABLE_ACS=2
FAILED_DISABLE_ACS=3
for BDF in `lspci -d "*:*:*" | awk '{print $1}'`; do

    # skip if it doesn't support ACS
    setpci -v -s ${BDF} ECAP_ACS+0x6.w > /dev/null 2>&1
    if [ $? -ne 0 ]; then
            #echo "${BDF} does not support ACS, skipping"
            continue
    fi

    echo "Disabling ACS on `lspci -s ${BDF}`"
    setpci -v -s ${BDF} ECAP_ACS+0x6.w=0000
    if [ $? -ne 0 ]; then
        if [ $EXITCODE -eq 0 ]; then # Only set EXITCODE on first setpci error
             EXITCODE=$ERR_DISABLE_ACS
        fi
        echo "Error disabling ACS on ${BDF}"
            continue
    fi
    NEW_VAL=`setpci -v -s ${BDF} ECAP_ACS+0x6.w | awk '{print $NF}'`
    if [ "${NEW_VAL}" != "0000" ]; then
        if [ $EXITCODE -eq 0 ]; then # Only set EXITCODE on first setpci failed
            EXITCODE=$FAILED_DISABLE_ACS
        fi
        echo "Failed to disable ACS on ${BDF}"
            continue
    fi
done

#Query ACS
for BDF in `lspci -d "*:*:*" | awk '{print $1}'`; do
  lspci -vvv|grep 'ACSCtl:.*SrcValid-' &>/dev/null && echo "${BDF} ACS disabled" || cho "${BDF} ACS enabled"
done

exit $EXITCODE

