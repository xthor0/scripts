#!/bin/bash

# allow XFCE to fully load
sleep 10

# adjust displays
xrandr --output VIRTUAL1 --off --output DP3 --off --output DP2 --off --output DP1 --off --output HDMI3 --mode 1920x1200 --pos 1920x0 --rotate normal --output HDMI2 --mode 1920x1200 --pos 0x0 --rotate normal --output HDMI1 --off --output VGA1 --off
sleep 3

conky
exit 0
