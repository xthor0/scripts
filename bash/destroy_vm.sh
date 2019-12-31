#!/bin/bash

function usage() {
    echo "`basename $0`: Destroy libvirt virtual machine."
    echo "Usage:

`basename $0` -n <name of VM> [ -d ]

-d: Remove VM files from disk. Use with caution, dumbass."
    exit 255
}


# get command-line args
while getopts "n:d" OPTION; do
    case $OPTION in
        n) vmname="$OPTARG";;
        d) delete="yes";;
        *) usage;;
    esac
done

# validate args
if [ -z "${vmname}" ]; then
    echo "You must specify a VM name."
    usage
fi

# does the VM even exist?
virsh list --all | grep -q ${vmname}
if [ $? -eq 0 ]; then
    # we need to find the dirname of the drive location

    # decide if we're REALLY deleting it
    if [ -n "${delete}" ]; then
        virsh undefine --remove-all-storage --domain ${vmname}
        retval=$?
    else
        virsh undefine --domain ${vmname}
        retval=$?
    fi

    if [ ${retval} -eq 0 ]; then
        echo "VM ${vmname} deleted successfully."
    else
        echo "Error! See output above."
    fi
else
    echo "VM ${vmname} does not exist."
    exit 255
fi

# end
exit 0
