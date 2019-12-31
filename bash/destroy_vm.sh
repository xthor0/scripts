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
    # forcefully power off the VM
    virsh destroy "${vmname}"

    # find out what directory these VMs were in
    virsh dumpxml --domain "${vmname}" | grep 'source file' | awk '{ print $2 }' | cut -d \' -f 2 | while read line; do
        vmdir="$(dirname "${line}")"
        if [ -n "${last_vmdir}" ]; then
            if [ "${last_vmdir}" == "${cur_vmdir}" ]; then
                last_vmdir="$(dirname "${line}")"
            else
                echo "How the hell did you create this VM? You'll have to clean up manually."
            fi
        fi
    done

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

    # make sure vmdir is empty, and then remove it
    find "${vmdir}" | read
    if [ $? -eq 0 ]; then
        rmdir "${vmdir}"
    else
        echo "Oops, something didn't clean up right."
        echo "${vmdir} is not empty!"
    fi
else
    echo "VM ${vmname} does not exist."
    exit 255
fi

# end
exit 0
