#!/bin/bash
#
topdir=$(dirname $(realpath $0))

source $topdir/passwd.sh
export hostlist=$topdir/hosts.list

query_hgx_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|tail -n 100|while read i
  do
    curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries/${i}"|jq '.Created,.Severity,.Message'|paste - - -|tr -s '[:space:]'
  done
}

clear_hgx_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Actions/LogService.ClearLog"
}

query_sys_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|tail -n 100|while read i
  do
    curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Entries/${i}"|jq '.Created,.Severity,.Message'|paste - - -|tr -s '[:space:]'
  done
}

clear_sys_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST "https://${bmc_ip}/redfish/v1/Systems/System_0/LogServices/EventLog/Actions/LogService.ClearLog"
}

cycle_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${bmc_ip}/redfish/v1/Systems/System_0/Actions/ComputerSystem.Reset -d '{"ResetType": "ForceOff"}'
  sleep 2
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${oob_ip}/redfish/v1/Chassis/BMC_0/Actions/Oem/NvidiaChassis.AuxPowerReset -d '{"ResetType": "AuxPowerCycle"}'
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
