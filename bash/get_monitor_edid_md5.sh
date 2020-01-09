#!/bin/bash

# let's figure out which monitors are attached and what port they are attached to
DEVICES=$(find /sys/class/drm/*/status)

while read dev ; do 
    if [ $(cat ${dev}) == "connected" ]; then
        dirname ${dev}
        cat $(dirname ${dev})/edid | md5sum | awk '{ print $1 }'
    fi 
done <<< "${DEVICES}"

exit 0