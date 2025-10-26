#!/bin/bash
#
#Ref: https://docs.nvidia.com/dgx/dgxgb200-user-guide/compute-tray-redfish-commands.html
#
topdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $topdir/passwd.sh
export hostlist=$topdir/hosts.list

query_hgx_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|tail -n 300|while read i
  #curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|while read i
  do
    curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries/${i}"|jq '.Created,.Severity,."CPER"."Oem"."Nvidia"."Nvidia"."Signature",.Message'|paste - - - -|tr -s '[:space:]'
  done
}

clear_hgx_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Actions/LogService.ClearLog"
}

query_sys_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|tail -n 300|while read i
  #curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|while read i
  do
    curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Entries/${i}"|jq '.Created,.Severity,.Message'|paste - - -|tr -s '[:space:]'
  done
}

clear_sys_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Actions/LogService.ClearLog"
}

cycle_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset -d '{"ResetType": "ForceOff"}'
  sleep 1
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${bmc_ip}/redfish/v1/Chassis/BMC_0/Actions/Oem/NvidiaChassis.AuxPowerReset -d '{"ResetType": "AuxPowerCycle"}'
  sleep 1
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset -d '{"ResetType": "On"}'
}

configure_bf3(){
  #1. Set “EnablePcieNicTopology“ to true and "Socket0Pcie6DisableOptionROM“ to false
  curl -k -s --user "${bmc_username}:${bmc_password}" -X PATCH https://${bmc_ip}/redfish/v1/Systems/System_0/Bios/Settings -d '{"Attributes": {"EGM": true, "Socket0Pcie0MaxPayloadSize": "Auto", "Socket0Pcie6DisableOptionROM": false , "Socket1Pcie6DisableOptionROM": false, "EnablePcieNicTopology": false}}'
  sleep 3
  #2. Check the pending settings
  curl -k -s --user "${bmc_username}:${bmc_password}" -X GET -H "Content-Type: application/json" https://${bmc_ip}/redfish/v1/Systems/System_0/Bios/Settings
  #sleep 10
  ##3. Reboot system
  #curl -k -s --user "${bmc_username}:${bmc_password}" -X POST https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/#ComputerSystem.Reset -d '{"ResetType":"PowerCycle"}'
  ##4. Check the modified items
  #curl -k -s --user "${bmc_username}:${bmc_password}" -X GET -H "Content-Type: application/json" https://${bmc_ip}/redfish/v1/#Systems/System_0/Bios|grep -E 'Socket0Pcie6DisableOptionROM|EnablePcieNicTopology'
  #curl -k -s --user "${bmc_username}:${bmc_password}" -X GET -H "Content-Type: application/json" https://${bmc_ip}/redfish/v1/Registries/BiosAttributeRegistry/BiosAttributeRegistry|grep -E 'Socket0Pcie6DisableOptionROM|EnablePcieNicTopology' -A2
}

query_gb200_macs(){
  #curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName'|paste - -|grep PXEv4|awk '{print $NF}'|tr ')' ':'|cut -f2 -d':'|sort|while read i; do
  #echo $i | sed 's/../&:/g'|cut -c 1-17
  #done
  curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName,.UefiDevicePath'|paste - - -|grep PXEv4 \
  |sed -e 's:/MAC:"MAC:g' -e 's:/IPv4:"IPv4:g'|awk -F'"' '{print $2, $7, $6}'|while read boot macA busB
  do
    echo OS ${boot} $(echo ${macA}|cut -c5-16|sed 's/../&:/g'|cut -c 1-17) ${busB}
  done
  curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Managers/BMC_0/EthernetInterfaces|jq '.Members[]."@odata.id"'|tr -d '"'|while read i
  do
    curl -s -k -u $bmc_username:$bmc_password "https://${bmc_ip}$i"|jq '.Id,.MACAddress' | paste - - | tr -s ' ' | xargs -I {} echo BMC {}
  done
}

query_gb200_bootorder(){
  tmpf=$(mktemp)
  curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName,.UefiDevicePath'|paste - - - > $tmpf
  curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0?\$select=Boot/BootOrder|jq '.Boot.BootOrder[]'|while read i; do
    grep -w $i $tmpf
  done
  rm -f $tmpf
}

network_boot_gb200(){
  #target_pci="PciRoot(0x6)"  ##enP6p3s0f0np0
  #target_boots=($(curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName,.UefiDevicePath'|paste - - -|grep PXEv4 | grep "${target_pci}" | awk '{print $1}'))
  target_boots=($(curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName,.UefiDevicePath'|paste - - -|grep PXEv4|grep -v USB|awk '{print $1}'))
  all_pxev4_boots=($(curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName'|paste - -|grep PXEv4|awk '{print $1}'))
  pxev4_boots=(${target_boots[*]} $(echo ${all_pxev4_boots[*]} ${target_boots[*]}|tr ' ' '\n'|sort|uniq -c|grep -v -w ' 2 '|awk '{print $NF}'))
  #pxev4_boots=($(curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0/BootOptions?\$expand=.|jq '.Members[]|.Id,.DisplayName'|paste - -|grep PXEv4|awk '{print $1}'))
  old_boots=($(curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0?\$select=Boot/BootOrder|jq '.Boot.BootOrder[]'))
  pad_boots=($(echo ${pxev4_boots[*]} ${old_boots[*]}|tr ' ' '\n'|sort|uniq -c|grep -v -w ' 2 '|awk '{print $NF}'))
  new_boots=$(echo ${pxev4_boots[*]} ${pad_boots[*]}|tr -s ' ' ',')
  echo OLD_BOOT_ORDER=${old_boots[*]}|tr ' ' ','
  echo NEW_BOOT_ORDER=$new_boots
  curl -s -k -u $bmc_username:$bmc_password -X PATCH https://$bmc_ip/redfish/v1/Systems/System_0/Settings -d "{\"Boot\":{\"BootOrder\": [${new_boots}]}}"
  #ipmitool -I lanplus -H ${bmc_ip} -U ${bmc_username} -P ${bmc_password} chassis bootdev pxe
  echo "reboot node"; sleep 1
  curl -s -k -u $bmc_username:$bmc_password  -X POST https://$bmc_ip/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset -d '{"ResetType": "PowerCycle"}'
  #curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset -d '{"ResetType": "ForceOff"}'
  #sleep 1
  #curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset -d '{"ResetType": "On"}'
}

sensors(){
curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/TelemetryService/MetricReports|jq '.Members[]."@odata.id"'|tr -d '"'|while read i; do
  curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip${i}|jq -r '.MetricValues[]|[.Timestamp,.MetricProperty,.MetricValue]|@tsv' | column -t
done
}

query_firmware(){
curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/UpdateService/FirmwareInventory|jq '.Members[]."@odata.id"'|tr -d '"'|while read i; do
  curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip${i}|jq -r '[.Id,.Version]|@tsv'|column -t
done
}

power_ac_cycle(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType":"AuxPowerCycleForce"}' \
  https://${bmc_ip}/redfish/v1/Chassis/BMC_0/Actions/Oem/NvidiaChassis.AuxPowerReset
}

power_graceful_shutdown(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "GracefulShutdown"}' \
  https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset
}

power_force_off(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "ForceOff"}' \
  https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset
}

power_on(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "On"}' \
  https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset
}

power_cycle(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "PowerCycle"}' \
  https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset 
}

power_status(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  https://${bmc_ip}/redfish/v1/Systems/System_0|jq '.PowerState' 
}

hmc_graceful_restart(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "GracefulRestart"}' \
  https://${bmc_ip}/redfish/v1/Managers/HGX_BMC_0/Actions/Manager.Reset
}

hmc_force_restart(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "ForceRestart"}' \
  https://${bmc_ip}/redfish/v1/Managers/HGX_BMC_0/Actions/Manager.Reset
}

bmc_restart(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X POST \
  -d '{"ResetType": "ForceRestart", "Description": "BMC bundle update curl"}' \
  https://${bmc_ip}/redfish/v1/Managers/BMC_0/Actions/Manager.Reset
}

add_user(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"UserName": "supperuser", "Password": "P@ss$1234", "RoleId": "Operator"}' \
  https://${bmc_ip}/redfish/v1/AccountService/Accounts
}

update_passwd(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -H "Content-Type: application/json" \
  https://${bmc_ip}/redfish/v1/AccountService/Accounts/${bmc_username} \
  --data '{ "Attributes": { "Password": "NEW_PASSWORD" } }'
}

enable_ipmi(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  -X PATCH \
  -d '{ "IPMI": {"ProtocolEnabled": true} }' \
  https://${bmc_ip}/redfish/v1/Managers/BMC_0/NetworkProtocol
}

check_ipmi(){
  curl -k -s --user "${bmc_username}:${bmc_password}" \
  https://${bmc_ip}/redfish/v1/Managers/BMC_0/NetworkProtocol | jq '.IPMI'
}

get_serial_number(){
curl -s -k -u $bmc_username:$bmc_password https://$bmc_ip/redfish/v1/Systems/System_0|jq -r '.Id,.SerialNumber'|paste - -
}
