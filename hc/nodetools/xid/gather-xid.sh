pdsh -R ssh -w GB200-POD1-A[03,05,07,09,11,13,15,17]-Node[01-18],GB200-POD1-B[02,04,06,08,10,12,14,16]-Node[01-18],GB200-POD2-E[03,05,07,09,11,13,15,17]-Node[01-18],GB200-POD2-F[02,04,06,08,10,12,14,16]-Node[01-18] <<- 'EOF'
bash /home/cmsupport/workspace/hc/nodetools/xid/xid.sh ||true
EOF
