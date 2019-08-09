#!/bin/bash

# right now, the goal is just to wrap creating a new cloud-image Ubuntu VM in a bash script
# eventually, it'll need to be extended to include CentOS and any other images I might want to try...

# display usage
function usage() {
    echo "`basename $0`: Build a VM from a cloud-init based image."
    echo "Usage:

`basename $0` -n <name of VM> -f <os flavor> [ -i <static IP> -s <size of hard drive in MB> ] [ -r <RAM in GB> ] [ -c <cpu cores> ]"
    exit 255
}

function bad_taste() {
    echo "Sorry, I don't know what flavor of Linux ${flavor} is."
    echo
    echo "Valid choices: bionic, centos7, centos7-1804"
    exit 255
}

function is_int() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "Error: $2 must be specified as integer"
        usage
        exit 255
    fi
}

# get command-line args
while getopts "n:i:f:s:c:r:" OPTION; do
    case $OPTION in
        n) vmname="$OPTARG";;
        i) ipaddr="$OPTARG";;
        f) flavor="$OPTARG";;
        s) storage="$OPTARG";;
        c) cpu="$OPTARG";;
        r) ram="$OPTARG";;
        *) usage;;
    esac
done

# verify command-line args
if [ -z "${vmname}" -o -z "${flavor}" ]; then
    usage
fi

# if storage is not specified, default to 8GB
if [ -z "${storage}" ]; then
  storage=8192
else
    # must be an integer
    is_int ${storage} "-s"

    # image comes in 2GB flavor, make sure value specified is larger
    if [ ${storage} -le 2048 ]; then
        echo "Values less than 8GB not accepted, defaulting to 8GB"
        storage=8192
    fi
fi

# RAM and CPU default to 1 each (1GB RAM, 1 CPU core)
if [ -n "${ram}" ]; then
    # must be an integer
    is_int ${ram} "-r"

    # specified in GB, converted to MB
    memory=$(expr ${ram} \* 1024)
else
    memory=1024
fi

if [ -n "${cpu}" ]; then
    # must be an integer
    is_int ${cpu} "-c"
else
    cpu=1
fi

# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="${HOME}/tmp/cloudimage/bionic-server-cloudimg-amd64.vdi";;
    centos7) image="${HOME}/tmp/cloudimage/centos7-1905.vdi";;
    centos7-1804) image="${HOME}/tmp/cloudimage/centos7-1804.vdi";;
    *) bad_taste;;
esac

### download locations for images
# CentOS 7: https://cloud.centos.org/centos/7/images/?C=M;O=D -- download the qcow2.xz images
# Ubuntu: https://cloud-images.ubuntu.com/
# conversion example: qemu-img convert -f qcow2 -O vdi CentOS-7-x86_64-GenericCloud-1905.qcow2 ../centos7-1905.vdi

# set a variable here, just in case Oracle ever changes shit
vbm="/usr/bin/vboxmanage"

### BEGIN
# make sure the VM doesn't already exist...
vboxmanage list vms | grep -qw ${vmname}
if [ $? -eq 0 ]; then
    echo "Error: ${vmname} already exists!"
    exit 255
fi

# my idea was to wrap all the commands in an array, and then iterate through
cmdlist=()
cmdlist=(
    "${vbm} createvm --name ${vmname} --ostype Ubuntu_64 --register"
    "${vbm} modifyvm ${vmname} --memory ${memory}"
    "${vbm} modifyvm ${vmname} --cpus ${cpu}"
    "${vbm} modifyvm ${vmname} --nic1 hostonly --hostonlyadapter1 vboxnet0"
    "${vbm} clonemedium disk ${image} ~/VirtualBox\ VMs/${vmname}/${vmname}.vdi"
    "${vbm} modifymedium disk ~/VirtualBox\ VMs/${vmname}/${vmname}.vdi --resize ${storage}"
    "${vbm} storagectl ${vmname} --name SATA\ Controller --add sata --controller IntelAhci --portcount 2"
    "${vbm} storageattach ${vmname} --storagectl SATA\ Controller --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/${vmname}/${vmname}.vdi"
    "${vbm} modifyvm ${vmname} --uart1 0x03f8 4 --uartmode1 disconnected"
)

# build the VM
IFS=""
for cmd in ${cmdlist[*]}; do
    eval ${cmd}
    if [ $? -ne 0 ]; then
        echo "Command exited with non-zero status."
        echo "Command: "
        echo "${cmd}"
        exit 255
    fi
done

# create a temp dir for cloud-init iso
ISOTMP=$(mktemp -d)

cat << EOF | tee ${ISOTMP}/meta-data
instance-id: 1
local-hostname: ${vmname}
EOF
if [ $? -ne 0 ]; then
    echo "Error creating ${ISOTMP}/meta-data."
    exit 255
fi

cat << EOF | tee ${ISOTMP}/user-data
#cloud-config
users:
    - name: root
      passwd: toor
      ssh_authorized_keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfu9au0EkA02pnruvqLcquikJim4VgQg61YxwG0LauDv+qM0j4EPDfzQtN3GMfyPs/i79NeNNndvfc2vqYJt8sVwjegoNF9h8jDytaWZ7zzblhY7qBkwtAVZ6ADgTY/w28CkB80dRPey2E4FGxING6AzieYwoHsKmaMt6IumOJlo01HoeouW7OP8qg51n8EHKmov5oA4DzzDx/UkS0aDDKpp38hIj0DHkcK8jhi5eZoEM7hOgaW+Efj6t/XzpoOhQVytsJXxqzZ/+4UDVfJ3FTQLmI+hdymbyxYL5i2FCK5kMldGyZuZz9h9ikM9xHWSmKIeTevut9/chveUR/W/E2qqziqm8fCoZZ2WIHfhy+Bt0OcLUro2Gpe7S0i8uCbvNK60OpE+hf9GxAv+G0UUCuSxJtKqrpgi5xNifvXaT3pk5Uxr/1+g+tiMyoaZxCmJPz7IZU7y9lurTAhYT0HgkcU4OZpGS1/x+rGu2f0un3UkUJyYFpgjfjw9iu9Y/0H7k= bbrown@bbrown-l
timezone: America/Denver
runcmd:
    - touch /etc/cloud/cloud-init.disabled
    - eject cdrom
EOF
if [ $? -ne 0 ]; then
    echo "Error creating ${ISOTMP}/user-data - exiting."
    exit 255
fi

## this works! I could use it to config static IPs, if I need to.
if [ -n "${ipaddr}" ]; then
    cat << EOF | tee ${ISOTMP}/network-config

## /network-config on NoCloud cidata disk
## version 1 format
## version 2 is completely different, see the docs
## version 2 is not supported by Fedora
---
version: 1
config:
- type: physical
  name: enp0s3
  subnets:
  - type: static
    address: ${ipaddr}
    netmask: 255.255.255.0
    routes:
    - network: 0.0.0.0
      netmask: 0.0.0.0
      gateway: 10.187.88.1
- type: nameserver
  address: [10.187.88.1]
  search: [.lab]
EOF
    if [ $? -ne 0 ]; then
        echo "Error creating ${ISOTMP}/network-config - exiting."
        exit 255
    fi
fi

# generate ISO
pushd ${ISOTMP}
genisoimage -output ~/VirtualBox\ VMs/${vmname}/${vmname}-ci.iso -volid cidata -joliet -r . 
if [ $? -ne 0 ]; then
    echo "Uh-oh - genisoimage failed!"
    exit 255
fi
popd 

# clean up temp
rm -rf ${ISOTMP}

# attach ISO to VM
${vbm} storageattach ${vmname} --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium ~/VirtualBox\ VMs/${vmname}/${vmname}-ci.iso
if [ $? -ne 0 ]; then
    echo "Error attaching ${vmname}-ci.iso to ${vmname} - exiting."
    exit 255
fi

# boot up the VM
${vbm} startvm ${vmname} --type headless

# and... we're done
echo "Done!"

exit 0
