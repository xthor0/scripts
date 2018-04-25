#!/bin/bash

syndaemon -i 0.5 -K -R -d &
synclient PalmDetect=1 PalmMinWidth=6 PalmMinZ=100 VertTwoFingerScroll=1 TapButton1=0 &

exit 0
