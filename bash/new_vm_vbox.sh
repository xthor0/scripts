#!/bin/bash

# display usage
function usage() {
    echo "`basename $0`: Build custom VirtualBox VM."
    echo "Usage:

`basename $0` -n <name of new vm> [ -i <path to iso> ]"
    exit 255
}

# get command-line args
while getopts "n:i:" OPTION; do
    case $OPTION in
        n) servername="${OPTARG}";;
        i) iso="${OPTARG}";;
        *) usage;;
    esac
done

# ensure argument was passed
if [ -z "${servername}" ]; then
  usage
fi

# let's begin

if [ -d ${HOME}/VirtualBox\ VMs/${servername} ]; then
    echo "${servername} already exists. Exiting."
    exit 255
fi

# create stuff
vboxmanage createvm --name ${servername} --ostype Debian --register
vboxmanage modifyvm ${servername} --memory 1024
vboxmanage modifyvm ${servername} --nic1 hostonly --hostonlyadapter1 vboxnet0
vboxmanage createhd --filename ~/VirtualBox\ VMs/${servername}/${servername}.vdi --size 8000 --format VDI
vboxmanage storagectl ${servername} --name "IDE Controller" --add ide --controller PIIX4
vboxmanage storageattach ${servername} --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/${servername}/${servername}.vdi
if [ -n "${iso}" ]; then
    if [ -f ${iso} ]; then
        vboxmanage storageattach ${servername} --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium ${iso}
    else
        echo "Unable to find ${iso} - can't attach it to the VM!"
    fi
fi
vboxmanage startvm ${servername}

# I need to update this for more modern OSs, probably...