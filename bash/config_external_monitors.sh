#!/bin/bash

# I disabled this, but... just in case it comes back when I reboot:
pidof /usr/libexec/kf5/kscreen_backend_launcher >& /dev/null
if [ $? -eq 0 ]; then
    killall kscreen_backend_launcher
fi

# set up external monitors, if they are attached
# it's a hack. what can I say. At home, and at work, I have 2x external 4k monitors.
# so, if there are 3 connected at login... I'll just assume they are my 4k monitors. :)
if [ $(xrandr -q | grep -w connected | wc -l) -eq 3 ]; then
    xrandr --output VIRTUAL1 --off --output eDP1 --off --output DP1 --primary --mode 3840x2160 --pos 0x0 --rotate normal --output HDMI2 --off --output HDMI1 --off --output DP2 --mode 3840x2160 --pos 3840x0 --rotate normal
else
  # override the DPI settings, so we can actually SEE the fonts.
  # I did a lot of googles... as of 2019.05.28, there is no way for Linux
  # to run multiple displays with differing DPI settings - BUMMER
  echo 'Xft.dpi: 144' | xrdb -override
  xrandr --output eDP1 --mode 3840x2160 --primary --pos 0x0 --rotate normal --output HDMI1 --off --output HDMI1 --off --output DP2 --off --output DP1 --off
fi

exit 0