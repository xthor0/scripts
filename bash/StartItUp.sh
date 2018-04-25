#!/bin/bash

# let the system start up
sleep 5

# fire up the touchpad protection
syndaemon -i 1 -t -K -d

# check the screen -- are we docked?
displaystatus=$(xrandr -q | grep ^DP-1 | awk '{ print $2 }')

if [ "${displaystatus}" == "connected" ]; then
	xrandr --output VGA-0 --off --output LVDS-0 --off --output DP-5 --off --output DP-4 --off --output DP-3 --off --output DP-2 --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-1 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-0 --off
fi

# start up apps
(pidgin &)&
(google-chrome &)&
(firefox &)&
(xchat &)&
(conky &)&

# the end
exit 0
