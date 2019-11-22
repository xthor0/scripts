#!/usr/bin/env bash

# right now, the goal is just to wrap creating a new cloud-image Ubuntu VM in a bash script
# eventually, it'll need to be extended to include CentOS and any other images I might want to try...

CLOUDINIT_IMG=/tmp/cloudinit.img

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
    echo "Valid choices: bionic, centos7, centos7-1805"
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

# todo: build in static IP functionality
# get command-line args
while getopts "n:i:f:s:c:r:" OPTION; do
    case $OPTION in
        n) vmname="$OPTARG";;
        f) flavor="$OPTARG";;
        s) storage="$OPTARG";;
        c) cpu="$OPTARG";;
        r) ram="$OPTARG";;
        i) ipaddr="$OPTARG";;
        *) usage;;
    esac
done

# verify command-line args
if [ -z "${vmname}" -o -z "${flavor}" ]; then
    usage
fi

# if storage is not specified, default to 8GB
if [ -z "${storage}" ]; then
  storage=12288
else
    # must be an integer
    is_int ${storage} "-s"

    # image comes in 2GB flavor, make sure value specified is larger
    if [ ${storage} -le 2048 ]; then
        echo "Values less than 8GB not accepted, defaulting to 12GB"
        storage=12288
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

### downloading and converting the images
# CentOS 7: https://cloud.centos.org/centos/7/images/?C=M;O=D
# Download the raw image, for example: https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1907.raw.tar.gz
# convert with this command:
# VBoxManage convertfromraw CentOS-7-x86_64-GenericCloud-1907.raw ~/cloudimage/centos7-1907.vdi --format vdi

# Ubuntu: https://cloud-images.ubuntu.com/
# Example: https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.vmdk
# convert with this command:
# vboxmanage clonemedium disk bionic-server-cloudimg-amd64.vmdk ~/cloudimage/bionic-server-cloudimg-amd64.vdi --format vdi

# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="${HOME}/cloudimage/bionic-server-cloudimg-amd64.vdi";;
    centos7) image="${HOME}/cloudimage/centos7-1907.vdi";;
    centos7-1805) image="${HOME}/cloudimage/centos7-1805.vdi";;
    *) bad_taste;;
esac

# set a variable here, just in case Oracle ever changes shit
# it's in different places on Linux than OSX
if [ -x /usr/bin/vboxmanage ]; then
    vbm="/usr/bin/vboxmanage"
elif [ -x /usr/local/bin/vboxmanage ]; then
    vbm="/usr/local/bin/vboxmanage"
else
    echo "I don't know where vboxmanage is. Exiting."
    exit 255
fi
 
### BEGIN
# some settings should be sourced from dotfiles
# otherwise, I'll have to write a separate script for my lab server (which uses bridged networking) than for my mac (which uses host-only)
if [ -f ${HOME}/.deploy_vm ]; then
    . ${HOME}/.deploy_vm
fi

# .deploy_vm can override the default machine folder - if it does, make it match
# otherwise, set the variable to match what virtualbox says
machine_folder=$(${vbm} list systemproperties | grep ^Default\ machine\ folder | cut -d \: -f 2 | sed "s/^[ \t]*//")
if [ -z "${VBOX_DIR}" ]; then
    VBOX_DIR="$(printf %q "${machine_folder}")"
else
    if [ "${machine_folder}" != "${VBOX_DIR}" ]; then
        ${vbm} setproperty machinefolder "${VBOX_DIR}"
    fi
fi

# if this is the first time virtualbox has been run, the VBOX_DIR folder may not exist
[ -d "${VBOX_DIR}" ] || mkdir -p "${VBOX_DIR}"

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
    "${vbm} clonemedium disk ${image} ${VBOX_DIR}/${vmname}/${vmname}.vdi"
    "${vbm} modifymedium disk ${VBOX_DIR}/${vmname}/${vmname}.vdi --resize ${storage}"
    "${vbm} storagectl ${vmname} --name sata_c1 --add sata --controller IntelAhci --portcount 2"
    "${vbm} storageattach ${vmname} --storagectl sata_c1 --port 0 --device 0 --type hdd --medium ${VBOX_DIR}/${vmname}/${vmname}.vdi"
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

# set up networking 
if [ -n "${NETWORK_MODE}" ]; then
    if [ "${NETWORK_MODE}" == "bridged" ]; then
        ${vbm} modifyvm ${vmname} --nic1 bridged --bridgeadapter1 ${BRIDGED_NIC}
    else 
        echo "Unknown network mode: ${NETWORK_MODE}"
        exit 255
    fi
else 
    ${vbm} modifyvm ${vmname} --nic1 hostonly --hostonlyadapter1 vboxnet0
fi 

# check above for error
if [ $? -ne 0 ]; then
    echo "Error: ${vmname} may have incorrect network settings. Exiting."
    exit 255
fi

TEMP_D=$(mktemp -d)

# generate image for cidata
dd if=/dev/zero of=${CLOUDINIT_IMG} count=1 bs=1M && mkfs.vfat -n cidata ${CLOUDINIT_IMG} 
if [ $? -eq 0 ]; then
  cat << EOF > ${TEMP_D}/meta-data
instance-id: 1
local-hostname: ${vmname}
EOF
  # generate the password with this command: mkpasswd --method=SHA-512 --stdin
  # ESCAPE YOUR DOLLAR SIGNS or stuff won't work!
  cat << EOF > ${TEMP_D}/user-data
#cloud-config
users:
  - name: xthor
    passwd: \$6\$w6ZFMnTUXqAniT9h\$0qwEbOsSRmI4alw6CZTB/.6i89GObwMk/yit7SaNSxvM10ENTIEjK0Pvl.4eC3tzGq1Dd81SKoyxdPSpiLM100
    lock_passwd: false
    primary_group: xthor
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
timezone: America/Denver
runcmd:
    - touch /etc/cloud/cloud-init.disabled
EOF
else
  echo "error creating cloudinit.img -- exiting."
  exit 255
fi

if [ -n "${ipaddr}" ]; then
  gateway=$(ip route | grep ^default | awk '{ print $3 }')
  cat << EOF > ${TEMP_D}/network-config
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
    address: ${ipaddr}/24
    gateway: ${gateway}
    dns_nameservers:
      - ${gateway}
    dns_search:
      - $(grep ^search /etc/resolv.conf  | awk '{ print $2 }')
EOF
fi

# write the config files to the vfat image
mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/meta-data :: && mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/user-data ::
if [ $? -ne 0 ]; then
  echo "Error writing user-data or meta-data to cloudinit.img."
  exit 255
fi

if [ -n "${ipaddr}" ]; then
  mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/network-config ::
  if [ $? -ne 0 ]; then
    echo "Error writing network-config to cloudinit.img."
    exit 255
  fi
fi

# convert cloudinit.img to something that vbox can handle
qemu-img convert -f raw -O vdi ${CLOUDINIT_IMG} ${VBOX_DIR}/${vmname}/cloudinit.img
if [ $? -ne 0 ]; then
  echo "Error running qemu-img convert. Exiting."
  exit 255
fi

# attach the cloudinit.img to the VM
${vbm} storageattach ${vmname} --storagectl sata_c1 --port 1 --device 0 --type hdd --medium ${VBOX_DIR}/${vmname}/cloudinit.img
if [ $? -ne 0 ]; then
  echo "Error attaching cloudinit.img to ${vmname}. Exiting."
  exit 255
fi

# boot up the VM
${vbm} startvm ${vmname} --type headless

# clean up files
rm -rf ${TEMP_D} ${CLOUDINIT_IMG}

# and... we're done
echo "Done!"

exit 0
