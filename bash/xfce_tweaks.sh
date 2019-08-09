#!/bin/bash

# set up external monitors, if they are attached
# it's a hack. what can I say. At home, and at work, I have 2x external 4k monitors.
# so, if there are 3 connected at login... I'll just assume they are my 4k monitors. :)
if [ $(xrandr -q | grep -w connected | wc -l) -eq 3 ]; then
  # Get rid of xfsettingsd so it doesn't screw up my monitor layout
  sleep 2 && killall xfsettingsd
  pidof xfsettingsd
  if [ $? -eq 1 ]; then
    xrandr --output HDMI-2 --off --output HDMI-1 --off --output DP-1 --primary --mode 3840x2160 --pos 0x0 --rotate normal --output eDP-1 --off --output DP-2 --mode 3840x2160 --pos 3840x0 --rotate normal
  fi
fi

# compositor for tear-free windows and some basic effects
compton -b

# launch conky, but with a delay to give the screens some time to come up
sleep 2 && conky &

# prompt for SSH passphrase, if key exists
(test -f $HOME/.ssh/id_rsa && ssh-add) &

# fix touchpad so I can right-click with 2 fingers
# you'll have to adjust the ID: xinput list | grep -i touchpad, find id for the one you want to tweak
xinput set-prop 13 "libinput Click Method Enabled" 0 1


exit 0
