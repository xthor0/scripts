#!/bin/bash

# this script takes a single argument (eventually will be parsed from vmware.guestinfo) and adds a new
# hard drive as a physical volume, then adds that volume to a volume group, and finally expands a logical
# volume to fill all available space

# this only works with VMware - if the device names change to something other than /dev/sda? this script
# will fail fantastically...

# also, if there is more than one volume group, this script also won't work.

# get the volume to expand from the command-line - and make sure it exists
if [ -z "$1" ]; then
    echo "You must specify the name of a logical volume to expand."
    exit 255
fi

logvols=$(/usr/sbin/lvs --rows | grep '^. *LV' | cut -d ' ' -f 4-)
# I could just grep here - but I'd rather make sure we have an EXACT match before proceeding
match=0
for vol in ${logvols}; do
    if [ "${vol}" == "${1}" ]; then
        match=1
        break
    fi
done

if [ $match == 0 ]; then
    echo "Sorry, I can't find a logical volume named ${1} on this system. Exiting."
    exit 255
fi

# get the name of the volume group
volgroup=$(vgs --readonly --rows | grep '^. *VG' | awk '{ print $2 }')

# make sure it's formatted as either ext4 or xfs - otherwise we're not coded for that
fstype=$(mount | grep ${volgroup}-${1} | awk '{ print $5 }')
if [ "$fstype" == "ext4" ]; then
    resize="resize2fs"
elif [ "$fstype" == "xfs" ]; then
    resize="xfs_growfs"
else
    echo "Unsupported filesystem: ${fstype}"
    exit 255
fi

# if /dev/sdb is already formatted as a physical volume, skip this step
pvs --readonly --rows | grep -q '^ *PV.*sdb'
if [ $? -eq 0 ]; then
    # if the operation has already completed, /dev/sdb will show 0 PFree
    pfree=$(/usr/sbin/pvs | grep /dev/sdb | awk '{ print $6 }')
    if [ $pfree -eq 0 ]; then
        echo "/dev/sdb has already been added and allocated - exiting!"
        exit 255
    else
        echo "/dev/sdb has already been added as a physical volume but shows free extents, continuing."
    fi
else
    /usr/sbin/pvcreate /dev/sdb && /usr/sbin/vgextend ${volgroup} /dev/sdb
    if [ $? -ne 0 ]; then
        echo "Error during operation - please check output."
        exit 255
    fi
fi

# by the time we reach this point, we expect to have /dev/sdb added to the volume group
pvs --readonly --rows | grep -q '^ *PV.*sdb'
if [ $? -eq 0 ]; then
    # now, let's expand the volume in question and add the space
    /usr/sbin/lvextend -l +100%FREE /dev/mapper/${volgroup}-${1} && ${resize} /dev/mapper/${volgroup}-${1}
    if [ $? -ne 0 ]; then
        echo "Error resizing filesystem!"
        exit 255
    else
        echo "Filesystem resized successfully!"
    fi
else
    echo "Error adding /dev/sdb to volume group ${volgroup} -- exiting!"
    exit 255
fi

exit 0
