#!/bin/bash

# first, let's see if we have HDMI2 connected. If we don't, we're out of the dock, and we don't want to screw with anything.
STATUS="`xrandr | grep ^DP-1 | awk '{ print $2 }'`"
if [ "$STATUS" == "connected" ]; then
	# set output to HDMI2, left of HDMI3
	xrandr --output DP-1 --right-of DP-2
	CONKYCOUNT=`ps ax | grep conky | grep -v grep | wc -l`
	if [ $CONKYCOUNT -ne 0 ]; then
		sleep 5
		killall conky
		conky
	fi
fi

exit 0
