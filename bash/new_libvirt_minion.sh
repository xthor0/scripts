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

vmdir=/home/xthor/vms
# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="/storage/cloudimage/bionic-server-cloudimg-amd64.img"; variant="ubuntu18.04";;
    centos7) image="/storage/cloudimage/CentOS-7-x86_64-GenericCloud-1907.img"; variant="centos7.0";;
    debian10) image="/storage/cloudimage/debian-10-openstack-amd64.qcow2"; variant="debian10";;
    debian9) image="/storage/cloudimage/debian-9-openstack-amd64.qcow2"; variant="debian9";;
    *) bad_taste;;
esac

# set vars for the ci image and the OS image
CLOUDINIT_IMG="${vmdir}/${vmname}-nocloud.img"
HDD_IMG="${vmdir}/${vmname}-os.qcow2"

# make sure they don't exist, or we exit
for file in "${CLOUDINIT_IMG}" "${HDD_IMG}"; do
    if [ -f "${file}" ]; then
        echo "${file} already exists -- exiting."
        exit 255
    fi
done

# create a temp dir for meta-data, and set vars for the images
TEMP_D=$(mktemp -d)

### we've passed all the basic checks - build the VM
# copy the source image to the destination
cp "${image}" ${HDD_IMG}
if [ $? -ne 0 ]; then
    echo "Error copying ${image} to ${HDD_IMG}. Exiting!"
    exit 255
fi

# generate image for cidata
dd if=/dev/zero of=${CLOUDINIT_IMG} count=1 bs=1M && mkfs.vfat -n cidata ${CLOUDINIT_IMG}
if [ $? -ne 0 ]; then
  echo "error creating cloudinit.img -- exiting."
  exit 255
fi

# meta-data is where the hostname gets set
cat << EOF > ${TEMP_D}/meta-data
instance-id: 1
local-hostname: ${vmname}.laptop.lab
EOF

# network-config is only necessary if we're setting a static IP address
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

# copy in the user-data for the $flavor specified
ci_dir="/home/xthor/git/scripts/cloud-init"
cp "${ci_dir}/${flavor}.user-data" ${TEMP_D}/user-data
if [ $? -ne 0 ]; then
    echo "Error copying ${ci-dir}/${flavor}.user-data to ${TEMP_D} -- exiting!"
    exit 255
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

# deploy the VM
virt-install --virt-type=kvm --name ${vmname} --ram ${memory} --vcpus ${cpu} --os-variant=${variant} --network=bridge=virbr0,model=virtio --graphics vnc --disk path=${HDD_IMG},cache=writeback --import --disk path=${CLOUDINIT_IMG},cache=none --noautoconsole

# done, I think :)
exit 0
