cd /home/cmsupport/workspace/hc/nodetools/xid/logs
grep Xid *|grep 149,|grep -v pid|sed -e 's:\[.*\]::g' -e 's#kernel: NVRM:#NVRM:#g'|sort|uniq -c | tee ../log.txt
grep Xid *|grep 145,|grep -v pid|sed -e 's:\[.*\]::g' -e 's#kernel: NVRM:#NVRM:#g'|sort|uniq -c | tee -a ../log.txt
grep Xid *|grep 137,|grep -v pid|sed -e 's:\[.*\]::g' -e 's#kernel: NVRM:#NVRM:#g'|sort|uniq -c | tee -a ../log.txt
grep Xid *|grep 121,|grep -v pid|sed -e 's:\[.*\]::g' -e 's#kernel: NVRM:#NVRM:#g'|sort|uniq -c | tee -a ../log.txt

echo "WARNNING: need RMA"
grep -E '149,.*\(0x004|149,.*\(0x00a' ../log.txt
