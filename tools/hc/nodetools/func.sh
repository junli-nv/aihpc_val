#!/bin/bash
#
topdir=$(dirname $(realpath $0))

source $topdir/passwd.sh
export hostlist=$topdir/hosts.list

query_hgx_bmc_log_gb200(){
  curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|tail -n 300|while read i
  #curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries"|jq '.Members[]."Id"'|tr -d '"'|sort -n|while read i
  do
    curl -k -s --user "${bmc_username}:${bmc_password}" "https://${bmc_ip}/redfish/v1/Systems/HGX_Baseboard_0/LogServices/EventLog/Entries/${i}"|jq '.Created,.Severity,.Message'|paste - - -|tr -s '[:space:]'
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
  sleep 2
  curl -k -s --user "${bmc_username}:${bmc_password}" -H 'Content-Type: application/json' -X POST https://${oob_ip}/redfish/v1/Chassis/BMC_0/Actions/Oem/NvidiaChassis.AuxPowerReset -d '{"ResetType": "AuxPowerCycle"}'
}

