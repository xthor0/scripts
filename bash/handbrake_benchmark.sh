#!/bin/bash

# log file for results
log=$(mktemp "${TMPDIR:-/tmp/}handbrake_bench.XXXXXXXXXX")
output_dir=$(mktemp -d "${TMPDIR:-/home/xthor/}handbrake_output.XXXXXXXXXX")

echo "Hardware info: " >> ${log}

if [ "$(uname -s)" == "Darwin" ]; then
	CPU="$(sysctl -n machdep.cpu.brand_string)"
    hwpreset='H.265 Apple VideoToolbox 2160p 4K'
    hbcli=/opt/homebrew/bin/HandBrakeCLI
    datecli=/opt/homebrew/bin/gdate
else
    CPU="$(grep ^model\ name /proc/cpuinfo | uniq | cut -d \: -f 2- | cut -b 2-)"
    echo "Video: " >> ${log}
    lspci | grep -iE 'VGA|3D|video' >> ${log}
    hwpreset='H.265 QSV 2160p 4K'
    hbcli="flatpak run --command=HandBrakeCLI fr.handbrake.ghb"
    datecli=/usr/bin/date
fi

# log CPU 
echo "CPU: ${CPU}" >> ${log}

# csv file if not exists
if [ ! -f results/results.csv ]; then
    echo "CPU,Preset,SourceFile,Width,OutputSize,Seconds,FPS" > results/results.csv
fi

for file in sources/*.mkv; do
    echo "Source file: ${file}"
    for preset in "${hwpreset}" 'HQ 2160p60 4K HEVC Surround'; do

        echo "Preset: ${preset}"
        
        preset_log=$(mktemp "${TMPDIR:-/tmp/}preset_log.XXXXXXXXXX")

        output="${output_dir}/$(basename "${file}" .mkv)_${preset}.mp4"
        ${hbcli} -Z "${preset}" -i "${file}" -o "${output}" -c 3,5,10 2> ${preset_log}

        # we need some info from the log
        START="$(grep 'Starting work at:' ${preset_log} | cut -c 30-)"
        END="$(grep 'Finished work at: ' ${preset_log} | cut -c 30-)"

        # Convert dates to Unix timestamps (seconds since 1970-01-01 UTC)
        START_SECS=$(${datecli} -d "$START" +%s)
        END_SECS=$(${datecli} -d "$END" +%s)

        total_seconds=$((END_SECS - START_SECS))

        # Calculate the components
        hours=$((total_seconds / 3600))        # 1 hour = 3600 seconds
        minutes=$(((total_seconds % 3600) / 60)) # Remainder of hours, then divide by 60 for minutes
        seconds=$(((total_seconds % 3600) % 60)) # Remainder of minutes for remaining seconds

        # Print the result
        echo "Total seconds: $total_seconds" >> ${log}
        echo "Formatted time: $hours hours, $minutes minutes, $seconds seconds" >> ${log}

        grep 'work: average encoding speed for job is' ${preset_log} >> ${log}

        du -h "${output}" | awk '{ print $1 }' >> ${log}

        # let's put everything in a cute CSV file
        SIZE="$(du -h "${output}" | awk '{ print $1 }')"
        SOURCESIZE="$(du -h "${file}" | awk '{ print $1 }')"
        SECONDS=${total_seconds}
        FPS="$(grep 'work: average encoding speed for job is' ${preset_log} | tail -n1 | awk '{ print $9 }' )"
        WIDTH="$(mediainfo "${file}" | grep ^Width | awk '{ print $3 $4 }')"
        echo "${CPU},${preset},${file},${WIDTH},${SIZE},${SECONDS},${FPS}" >> results/results.csv

        # nuke output file
        rm -f "${output}"

        # if I need to look at it later
        cat ${preset_log} >> ${log}

        # delete preset log 
        rm -f ${preset_log}
    done
    
done

# copy the log to results folder
cp ${log} results/$(date | md5sum | awk '{ print $1 }').log

# delete log and output directory
rm ${log}
rm -rf "${output_dir}"

# tell me you're done
curl -s \
  --form-string "token=a74zm3s7dc577532z2qet8fpkwuy6f" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Notification: handbrake benchmark completed" \
https://api.pushover.net/1/messages.json
