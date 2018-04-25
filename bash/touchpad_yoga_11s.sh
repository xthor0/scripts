#!/bin/bash

# kill any existing syndaemon processes (ubuntu likes to kick one off automatically)
if [ $(ps ax | grep syndaemon | grep -v grep | wc -l) -ne 0 ]; then
	killall syndaemon
fi

# spawn syndaemon with my settings
syndaemon -i 1 -K -d

# synclient options that may or may not be helpful
#synclient PalmDetect=1 PalmMinWidth=6 PalmMinZ=50 FingerHigh=46 FingerLow=46

# xinput settings I found on a web page that were supposed to help
xinput set-prop "SynPS/2 Synaptics TouchPad" "Device Accel Profile" 2
xinput set-prop "SynPS/2 Synaptics TouchPad" "Device Accel Constant Deceleration" 4
xinput set-prop "SynPS/2 Synaptics TouchPad" "Device Accel Adaptive Deceleration" 4
xinput set-prop "SynPS/2 Synaptics TouchPad" "Device Accel Velocity Scaling" 8
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Finger" 35 45 0
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Tap Time" 120
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Tap Move" 300
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Noise Cancellation" 20 20

# palm detection
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Palm Detection" 1
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Palm Dimensions" 4 1

# two finger scrolling
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Two-Finger Pressure" 150

# require a press of the touchpad to register as a click, not just a tap
xinput set-prop "SynPS/2 Synaptics TouchPad" "Synaptics Tap Time" 0
