#!/bin/bash
set +x
export USER=root
rm -rf $HOME/.vnc
mkdir $HOME/.vnc
chmod 700 $HOME/.vnc
echo "${VNC_PASSWORD:-P@ssw0rd}" | vncpasswd -f > $HOME/.vnc/passwd
chmod 0600 $HOME/.vnc/passwd
cat > $HOME/.vnc/xstartup << '__END__'
#!/bin/bash
xrdb $HOME/.Xresources
xsetroot -solid grey
export XKL_XMODMAP_DISABLE=1
/usr/bin/startlxde
__END__
chmod 755 $HOME/.vnc/xstartup

while :
do
  vncserver -kill :1 &>/dev/null
  vncserver -depth 24 -geometry ${GEOMOTRY:-1400x700} :1
  /usr/share/novnc/utils/launch.sh --listen 80 --vnc 127.0.0.1:5901 --web /usr/share/novnc/ &>/tmp/novnc.log &
  novncpid=$!
  vncpid=$(ps -ef|grep 'Xtightvnc.*:1'|grep -v grep|awk '{print $2}')
  while :; do [ -e /proc/${vncpid}/exe ] && sleep 10 || break; done
  kill $novncpid &>/dev/null
  pkill -9 ssh-agent &>/dev/null
  pkill -9 pcmanfm &>/dev/null
  rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 $HOME/.vnc/*.log
done
