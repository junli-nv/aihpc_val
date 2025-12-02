#!/bin/bash
cat > passwd.sh << 'EOF'
#!/bin/bash

#cmsh -> category -> gb200 -> bmcsettings -> get username/password
export bmc_username=root
export bmc_password=0penBmc

#cmsh -> device -> nvswitch -> accesssettings -> get username/password
export nvswitch_os_user=admin
export nvswitch_os_pass=admin

#cmsh -> device -> nvswitch -> bmcsettings -> get username/password
#OR
#cmsh -> category -> nvswitch -> bmcsettings -> get username/password
export nvswitch_bmc_user=root
export nvswitch_bmc_pass=JulietBmc@123

#cmsh -> device -> powershelf -> bmcsettings -> get username/password
export powershelf_bmc_user=root
export powershelf_bmc_pass=0penBmc
EOF

chmod +x passwd.sh