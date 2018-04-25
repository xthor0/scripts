#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Create a VirtualBox VM."
	echo "Usage:

`basename $0` -n <name of VM> -o <ostype> -h /path/to/vm.vdi -s <size of hard drive in MB> -m <memory in MB>"
	exit 255
}

# get command-line args
while getopts "n:o:h:s:m:" OPTION; do
	case $OPTION in
		n) vm_name="$OPTARG";;
		o) ostype="$OPTARG";;
		h) hdimage="$OPTARG";;
		s) hdsize="$OPTARG";;
		m) memory="$OPTARG";;
		*) usage;;
	esac
done

# validate input
if [ -z "${vm_name}" -o -z "${ostype}" -o -z "${hdimage}" -o -z "${hdsize}" -o -z "${memory}" ]; then
	usage
fi

# verify settings are correct
## ostype
while read os; do
	if [ "${os}" == "${ostype}" ]; then
		osmatch=1
	fi
done <<< $(vboxmanage list ostypes | grep ^ID | awk '{ print $2 }')
if [ -n ${osmatch} ]; then
	echo "Invalid OS type specified: $ostype"
	exit 255
fi

exit 255

# this is how I did it before
vboxmanage createhd --filename Win81.vdi --size 131072
vboxmanage createvm --name "Windows 8.1" --ostype Windows81_64 --register
vboxmanage storagectl "Windows 8.1" --name "SATA Controller" --add sata --controller IntelAHCI
vboxmanage storageattach "Windows 8.1" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium Win81.vdi
vboxmanage storagectl "Windows 8.1" --name "IDE Controller" --add ide
vboxmanage storageattach "Windows 8.1" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium /storage/ISO/SW_DVD5_Win_Pro_8.1_64BIT_English_MLF_X18-96634.ISO

vboxmanage modifyvm "Windows 8.1" --ioapic on
vboxmanage modifyvm "Windows 8.1" --vrde on
vboxmanage modifyvm "Windows 8.1" --boot1 dvd --boot2 disk --boot3 none --boot4 none
vboxmanage modifyvm "Windows 8.1" --memory 2048 --vram 128
vboxmanage modifyvm "Windows 8.1" --nic1 bridged --bridgeadapter1 em1

vboxmanage showvminfo "Windows 8.1"

VBoxManage storageattach "Windows 8.1" --medium /usr/share/virtualbox/VBoxGuestAdditions.iso --type dvddrive --storagectl 'IDE Controller' --port 1 --device 0

# starting VM
vboxmanage startvm "Windows 8.1" --type headless

# if you forgot to turn off VRDE in the VM config like I did
vboxmanage controlvm "Windows 8.1" vrde off
