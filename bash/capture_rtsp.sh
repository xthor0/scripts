#!/bin/bash

# I use this script on a Debian 11 system, with apt repo https://deb-multimedia.org/ installed
# and then I install livemedia-utils package with apt

# TODO: probably need a cleanup step, somewhere. in this script, or in cron
# might also want to wrap this in a Salt state, once I get my hack-a-NAS

cam_name=$1
cam_ip=$2
top_dir=/srv/nvr
log_dir=${top_dir}/logs

if [ -z "${cam_name}" -o -z "${cam_ip}" ]; then
    echo "Usage: ${0} <cam_name> <cam_ip>"
    exit 255
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    echo "** Trapped CTRL-C"
    echo "You probably have backgrounded OpenRTSP processes still running!"
    if [ -d /proc/${!} ]; then
        echo "Killing pid $!..."
        kill -s SIGHUP $!
    fi
    exit 255
}

function message() {
    echo "$(date) :: ${1}"
}

# create the log output dir if it does not exist
if [ ! -d ${log_dir} ]; then
    mkdir ${log_dir}
    if [ ! -d ${log_dir} ]; then
        echo "Unable to create ${log_dir} -- exiting."
        exit 255
    fi
fi

# run forever?
while true; do

# folder to store videos in
# TODO: we gonna delete old ones?
folder=$(date +%Y%m%d)
output_dir=${top_dir}/${folder}

# make sure it exists
if [ ! -d ${output_dir} ]; then
    mkdir ${output_dir}
    if [ ! -d ${output_dir} ]; then
        echo "Unable to create ${output_dir} -- exiting."
        exit 255
    fi
fi

pushd ${output_dir} >& /dev/null

# the idea here is to record up till the next 15 minute increment, and then record
# in 15 minute increments after that
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
        # if the first character in next_hour_mark is a zero, we have to remove it, and then put it back, I think?
        if [ ${next_hour_mark:0:1} -eq 0 ]; then
            next_hour_mark=${next_hour_mark:0:2}
        fi
        ((next_hour_mark=next_hour_mark + 1))
    fi
    next_minute_mark=0
fi

seconds_now=$(date +%s)
seconds_at_next_mark=$(date +%s -d "${day} ${next_hour_mark}:${next_minute_mark}")
((seconds_left = seconds_at_next_mark - seconds_now))

# filename format
filename="${cam_name}_$(date +%Y%m%d_%H%M).mp4"

# instead of using OpenRTSP right off, let's try sleep or something
message "OpenRTSP recording for ${seconds_left} seconds, to file ${filename}"

# we know how long we told this to run - so let's push it to the BG and monitor
openRTSP -B 10000000 -b 10000000 -4 -d ${seconds_left} -w 1920 -h 1080 -t rtsp://${cam_ip}/live0 2>> ${log_dir}/${cam_name}_$(date +%Y%m%d).log > ${filename} &
pid=$!

seconds_at_bg=$(date +%s)

# check output file size
filesize_last=$(du -k ${filename} | awk '{ print $1 }')
filesize_issue_count=0
filesize_issue_max=30

# begin loop to check how its going
while [ -d /proc/${pid} ]; do
    # sleep so we're not chewing up a ton of CPU
    sleep 1

    # check and see if the file size is increasing, otherwise OpenRTSP might need to be kicked
    filesize=$(du -k ${filename} | awk '{ print $1 }')
    if [ ${filesize} -eq ${filesize_last} ]; then
        let filesize_issue_count+=1
        if [ ${filesize_issue_count} -eq ${filesize_issue_max} ]; then
            message "Maximum wait reached for filesize not increasing, killing OpenRTSP and restarting."
            kill -s SIGHUP ${pid}
        else
            message "Output file ${filename} is not increasing in size -- now: ${filesize} last: ${filesize_last} (count ${filesize_issue_count} of ${filesize_issue_max})"
        fi
    else
        # if the counter has been incremented, we can reset it here, because it's consecutive checks we're worried about
        filesize_last=${filesize}
        filesize_issue_count=0
    fi

    # are we past the ${seconds_left} in elapsed time? if so, OpenRTSP might just need to be kicked and restarted
    #seconds_now=$(date +%s)
    #((elapsed=seconds_now-seconds_at_bg))
    #if [ ${elapsed} -gt ${seconds_left} ]; then
    #    # openRTSP might be about to exit, let's see
    #    sleep .5
    #    if [ -d /proc/${pid} ]; then
    #        message "OpenRTSP has been running longer than it should have been... killing ${pid}"
    #        kill ${pid}
    #    fi
    #fi
done

# go back to original dir, so we can start this whole process alllll over again
popd >& /dev/null

# end while true loop
done
