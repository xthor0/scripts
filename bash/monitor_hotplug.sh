#!/bin/bash

# shamelessly stolen: https://github.com/codingtony/udev-monitor-hotplug
# to trigger this, you need something like this in /etc/udev/rules.d/99-monitor-hotplug.rules
# ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="/usr/local/bin/monitor-hotplug.sh"


DEVICES=$(find /sys/class/drm/*/status)

#inspired by /etc/acpd/lid.sh and the function it sources

displaynum=`ls /tmp/.X11-unix/* | sed s#/tmp/.X11-unix/X##`
display=":$displaynum.0"
export DISPLAY=":$displaynum.0"

# from https://wiki.archlinux.org/index.php/Acpid#Laptop_Monitor_Power_Off
export XAUTHORITY=$(ps -C Xorg -f --no-header | sed -n 's/.*-auth //; s/ -[^ ].*//; p')


#this while loop declare the $HDMI1 $VGA1 $LVDS1 and others if they are plugged in
while read l
do
  dir=$(dirname $l);
  status=$(cat $l);
  dev=$(echo $dir | cut -d\- -f 2-);

  if [ $(expr match  $dev "HDMI") != "0" ]
  then
#REMOVE THE -X- part from HDMI-X-n
    dev=HDMI${dev#HDMI-?-}
  else
    dev=$(echo $dev | tr -d '-')
  fi

  if [ "connected" == "$status" ]
  then
    echo $dev "connected"
    declare $dev="yes";

  fi
done <<< "$DEVICES"


# I didn't want to code all the edge cases in. If we have dual displays connected, we use them
# and disable the laptop screen. Otherwise, 2k on the laptop screen.
if [ -n "${DP1}" -a -n "${DP2}" ]; then
  echo "DP1 and DP2 are plugged in"
  xrandr --output DP-1 --primary --mode 3840x2160 --pos 0x0 --rotate normal --output eDP-1 --off --output DP-2 --mode 3840x2160 --pos 3840x0 --rotate normal
else
  echo "No external monitors are plugged in"
  xrandr --output VIRTUAL1 --off --output eDP-1 --mode 2560x1440 --pos 0x0 --rotate normal --primary --output DP-1 --off --output HDMI-2 --off --output HDMI-1 --off --output DP-2 --off
fi

exit 0