#!/bin/bash

# vm cleanup script - remove the VM and clean up all the crap that goes with it

# display usage
function usage() {
    echo "`basename $0`: Delete a VirtualBox VM."
    echo "Usage:

`basename $0` -n <name of VM>"
    exit 255
}

# get command-line args
while getopts "n:f" OPTION; do
    case $OPTION in
        n) vmname="$OPTARG";;
        f) force="yes";;
        *) usage;;
    esac
done

# validate -n is present
if [ -z "${vmname}" ]; then
    usage
fi

# does this VM exist?
vboxmanage showvminfo ${vmname} >& /dev/null
if [ $? -eq 1 ]; then
    echo "VM does not exist: ${vmname}"
    exit 255
fi

# verify
if [ -z "${force}" ]; then
    echo "This action will REMOVE and DELETE the VM ${vminfo}!"
    echo "Please type YES in CAPS to continue:"
    read -s yesno
    if [ "${yesno}" != "YES" ]; then
        echo "Glad I asked..."
        exit 255
    fi
fi

# power VM off, if necessary
state=$(vboxmanage showvminfo ${vmname} | grep ^State  | awk '{ print $2 }')
if [ "${state}" == "running" ]; then
    echo "Powering off VM ${vmname}..."
    vboxmanage controlvm ${vmname} poweroff
    if [ $? -ne 0 ]; then
        echo "Error: ${vmname} won't power off"
        exit 255
    fi
elif [ "${state}" == "powered" ]; then
    echo "VM ${vmname} is already powered off"
else
    echo "Error: VM ${vmname} is in an unknown state: ${state}"
    exit 255
fi

# check if there was a CI iso created
vboxmanage list dvds | grep -q ${vmname}-ci.iso
if [ $? -eq 0 ]; then
    # remove the ISO used with cloud-init from virtualbox 
    echo "Detaching ISO from ${vmname}..."
    vboxmanage storageattach ${vmname} --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium emptydrive
    echo "Removing ${vmname}-ci.iso from media manager and deleting ISO..."
    vboxmanage closemedium dvd ~/VirtualBox\ VMs/${vmname}/${vmname}-ci.iso --delete
    if [ $? -ne 0 ]; then
        echo "Error: ~/VirtualBox\ VMs/${vmname}/${vmname}-ci.iso can't be closed."
        exit 255
    fi
else
    echo "${vmname}-ci.iso not found - continuing"
fi

# unregister/delete the VM
echo "Deleting VM ${vmname}..."
vboxmanage unregistervm ${vmname} --delete 
if [ $? -eq 0 ]; then
    echo "Done!"
else
    echo "Error deleting ${vmname}!"
fi

exit 0