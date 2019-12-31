#!/bin/bash

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
# Download the qcow2 image, for example: https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1907.qcow2c

# Ubuntu: https://cloud-images.ubuntu.com/
# Example: https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img

vmdir=/storage/vms
# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="/storage/cloudimage/bionic-server-cloudimg-amd64.img";;
    centos7) image="/storage/cloudimage/CentOS-7-x86_64-GenericCloud-1907.img";;
    *) bad_taste;;
esac

### we've passed all the basic checks - build the VM
test -d ${vmdir}/${vmname} || mkdir -p "${vmdir}/${vmname}"
if [ $? -ne 0 ]; then
    echo "Unable to create directory ${vmdir}/${vmname} -- exiting."
    exit 255
fi

# set some variables
TEMP_D=$(mktemp -d)
CLOUDINIT_IMG="${vmdir}/${vmname}/cloudinit.img"
HDD_IMG="${vmdir}/${vmname}/${vmname}.qcow2"

# copy the source image to the destination
cp "${image}" ${HDD_IMG}
if [ $? -ne 0 ]; then
    echo "Error copying ${image} to ${HDD_IMG}. Exiting!"
    exit 255
fi

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
  name: eth0
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

# we can clean up the temp dir now
rm -rf "${TEMP_D}"

## TODO: I need the ability to change the vlan!
# should be as easy as changing the bridged adapter.

# deploy the VM
virt-install --virt-type=kvm --name ${vmname} --ram ${memory} --vcpus ${cpu} --os-variant=centos7.0 --network=bridge=br-vlan03,model=virtio --graphics vnc --disk path=${HDD_IMG},cache=writeback --import --disk path=${CLOUDINIT_IMG},cache=none --noautoconsole

# done, I think :)
exit 0
