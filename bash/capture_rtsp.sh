#!/bin/bash

# I use this script on a Debian 11 system, with apt repo https://deb-multimedia.org/ installed
# and then I install livemedia-utils package with apt

# TODO: probably need a cleanup step, somewhere. in this script, or in cron
# might also want to wrap this in a Salt state, once I get my hack-a-NAS

cam_name=$1

cam_ip=$2

if [ -z "${cam_name}" -o -z "${cam_ip}" ]; then
    echo "Usage: ${0} <cam_name> <cam_ip>"
    exit 255
fi

while true; do

# I think I got all the cases?
minute=$(date +%M)
next_hour_mark=$(date +%H)
day="today"
if [ ${minute} -lt 15 ]; then
    next_minute_mark=15
elif [ ${minute} -lt 30 -a ${minute} -ge 15 ]; then
    next_minute_mark=30
elif [ ${minute} -lt 45 -a ${minute} -ge 30 ]; then
    next_minute_mark=45
else
    if [ ${next_hour_mark} -eq 23 ]; then
        next_hour_mark=0
        day="tomorrow"
    else
        ((next_hour_mark=next_hour_mark + 1))
    fi
    next_minute_mark=0
fi

#echo "DEBUGGING: next minute mark is ${next_minute_mark}, next hour mark is ${next_hour_mark}"

seconds_now=$(date +%s)
seconds_at_next_mark=$(date +%s -d "${day} ${next_hour_mark}:${next_minute_mark}")
((seconds_left = seconds_at_next_mark - seconds_now))

#echo "DEBUGGING: next minute mark is ${next_minute_mark}, next hour mark is ${next_hour_mark}"
#echo "DEBUGGING: $(date) :: if my math is right, it should be ${seconds_left} seconds till ${next_hour_mark} hour and ${next_minute_mark} minutes, zero seconds!"

# filename format
filename="${cam_name}_$(date +%Y%m%d_%H%M).mp4"

# instead of using OpenRTSP right off, let's try sleep or something
echo "Running OpenRTSP for ${seconds_left} seconds... and naming the file ${filename}..."

#echo "DEBUGGING: sleeping instead"
#sleep ${seconds_left}

# we know how long we told this to run - so let's push it to the BG and monitor
openRTSP -B 10000000 -b 10000000 -4 -d ${seconds_left} -w 1920 -h 1080 -t rtsp://${cam_ip}/live0 2>> openRTSP_${cam_name}.log > ${filename} &
pid=$!

seconds_at_bg=$(date +%s)
while [ -d /proc/${pid} ]; do
    # things I might want to check in here...
    # is the size of the file increasing? If not, either OpenRTSP is stuck, or RTSP on the camera has stopped working
    # are we past the ${seconds_left} in elapsed time? if so, OpenRTSP might just need to be kicked and restarted
    seconds_now=$(date +%s)
    ((elapsed=seconds_now-seconds_at_bg))
    if [ ${elapsed} -gt ${seconds_left} ]; then
        echo "OpenRTSP has been running longer than it should have been..."
        sleep 5
        kill -HUP1 ${pid}
    fi
    sleep 1
done

# we're going to have to do SOMETHING in the background, to see if the RTSP stream has stopped - I've had this problem a couple of times where RTSP has to be reset on the camera itself...

done
