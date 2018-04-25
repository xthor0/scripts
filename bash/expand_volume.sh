#!/bin/bash

# here's the workflow as I see it:
# 1. check and see if there is any free space on the physical device. if there isn't - we're done.
# 2. if there IS free space, we should resize the single PV and reboot. The script will have to resume.
## IF there is more than one PV - the script should exit without doing anything. I'll test this.
## since this will run via systemd - I should put in a check to see if uptime is greater than a few seconds.
## I don't want this running if someone accidentally kicks it off via a systemd script, instead of at boot.
# 3. after reboot, the PV should be extended, and then the specified VG should be extended.

# first let's figure out what PV we're dealing with. SHOULD be /dev/sda2 but I'll allow for the potential
# of device paths to change.

# count up the physical volumes present on this host
pvscount=$(pvs --readonly --rows | grep '^ *PV' | wc -l)

# exit if we're dealing with more than 1 - sorry, I really don't want to code for that
if [ $pvscount -ne 1 ]; then
    echo "I expect exactly ONE physical volume on this system, and I found ${pvscount}"
    echo "Verify this yourself, if you'd like: "
    echo "pvs --readonly --rows | grep '^ *PV' | wc -l"
    exit 255
fi

# get the name of the physical volume we're dealing with
pvol=$(pvs --readonly --rows | grep '^ *PV' | awk '{ print $2 }')

# this SHOULD be a partition of a larger device... let's check
devname=${pvol##/dev/}
#blockdev=${devname%?}
blockdev=$(basename "$(readlink -f "/sys/class/block/${devname}/..")")

# now let's see if we have any free space left on this block device
allocated=0
for dev in /dev/${blockdev}?; do
    size=$(blockdev --getsz ${dev})
    let "allocated += ${size}"
done

# get the total size of the parent block device
totsz=$(blockdev --getsz /dev/${blockdev})

# from that, we can figure out how much space is free on the device
freesz=$(expr ${totsz} - ${allocated})

# if it's not larger than 10MB (or, 10485760 bytes), we're not going to waste our time...
if [ ${freesz} -le 10485760 ]; then
    echo "Sorry, we only have ${freesz} bytes available on /dev/${blockdev}."
    echo "We really need 10485760 (10MB) to even bother... exiting."
    exit 255
fi

echo "Proceeding..."
# let's delete $pvol, re-create it to max out the disk, and then reboot
sfdisk=$(/sbin/sfdisk -d /dev/${blockdev} | grep ${devname})
echo $sfdisk | cut -d , -f 1,3
