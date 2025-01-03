#!/bin/bash

secs_to_human() {
    if [[ -z ${1} || ${1} -lt 60 ]] ;then
        min=0 ; secs="${1}"
    else
        time_mins=$(echo "scale=2; ${1}/60" | bc)
        min=$(echo ${time_mins} | cut -d'.' -f1)
        secs="0.$(echo ${time_mins} | cut -d'.' -f2)"
        secs=$(echo ${secs}*60|bc|awk '{print int($1+0.5)}')
    fi
    echo "Process complete : Time Elapsed : ${min} minutes and ${secs} seconds."
}

# start position
START=${SECONDS}

# run whatever you need to run
#sudo shred -v -n1 /dev/sda
RAND=$((RANDOM % 60))
echo sleeping ${RAND} seconds
sleep ${RAND}

# end position
END=${SECONDS}

# math
ELAPSED=$((${END} - ${START}))

# output message
message="`secs_to_human ${ELAPSED}`"

echo $message
pushover_me.sh $message
