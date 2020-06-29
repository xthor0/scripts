#!/bin/bash

image_dir=${HOME}/cloudimage
target_dir=/storage/images
user_data_file=${image_dir}/ci-data/user-data

# display usage
function usage() {
	echo "`basename $0`: Build a VM from a cloud image"
	echo "Usage:

`basename $0` -f <flavor> -n <FQDN of VM> [ -c <VCPUs> -r <RAM in GB> -s <storage in GB> ]"
	exit 255
}

function bad_taste() {
    echo "Sorry, I don't know what flavor of Linux ${flavor} is."
    exit 255
}

# get command-line args
while getopts "f:n:c:r:s:i:g:" OPTION; do
	case $OPTION in
		f) flavor="$OPTARG";;
		n) vmname="$OPTARG";;
        c) vcpus="$OPTARG";;
        r) ram="$OPTARG";;
        s) storage="$OPTARG";;
		i) ipaddr="${OPTARG}";;
        g) gateway="${OPTARG}";;
		*) usage;;
	esac
done

# validate - we need at least a flavor and a VM name
if [ -z "${flavor}" -o -z "${vmname}" ]; then
    usage
fi

# set some sane defaults if they aren't provided
if [ -z "${ram}" ]; then
    memory=2048
else
    memory=$((${ram} * 1024))
fi

if [ -z "${vcpus}" ]; then
    vcpus=1
fi

if [ -z "${storage}" ]; then
    storage="15"
fi

# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="${image_dir}/bionic-server-cloudimg-amd64.img"; variant="ubuntu18.04";;
    centos7) image="${image_dir}/CentOS-7-x86_64-GenericCloud.qcow2c"; variant="centos7.0";;
    centos8) image="${image_dir}/CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2"; variant="centos7.0";;
    debian10) image="${image_dir}/debian-10-openstack-amd64.qcow2"; variant="debian10";;
    debian9) image="${image_dir}/debian-9-openstack-amd64.qcow2"; variant="debian9";;
    *) bad_taste;;
esac

# make sure we're not clobbering a running domain - that'd be bad
target_hdd="${target_dir}/${vmname}.qcow2"
if [ -f ${target_hdd} ]; then
    echo "${target_hdd} already exists - exiting."
    exit 255
fi

virsh list --name --all | grep -qw ${vmname}
if [ $? -eq 0 ]; then
    echo "${vmname} found in \`virsh list\` output -- exiting."
    exit 255
fi

# make sure we have a cidata user-data file
if [ ! -f ${user_data_file} ]; then
    echo "Missing ${user_data_file} - you should, like, build one. Exiting."
    exit 255
fi

# make sure we have an image for flavor
if [ -f ${image} ]; then
    qemu-img convert -O qcow2 ${image} ${target_hdd}
    if [ $? -eq 0 ]; then
        qemu-img resize ${target_hdd} ${storage}G
        if [ $? -ne 0 ]; then
            echo "Error running qemu-img resize -- exiting."
            exit 255
        fi
    else
        echo "error running qemu-img convert -- exiting."
        exit 255
    fi
else
    echo "Missing ${image} file - exiting."
    exit 255
fi

# build the CI data
# this is where we'll store the file
ciimg=${target_dir}/${vmname}.cidata.img
truncate --size 2M ${ciimg} && /sbin/mkfs.vfat -n cidata ${ciimg}
if [ $? -ne 0 ]; then
    echo "Error prepping ${ciimg} -- exiting."
    exit 255
fi

# temp dir for the CI files
citmpdir=$(mktemp -d)

# meta-data
cat << EOF > ${citmpdir}/meta-data
instance-id: 1
local-hostname: ${vmname}
EOF

# user-data
cat ${user_data_file} > ${citmpdir}/user-data

# network config - only if static IP specified
if [ -n "${ipaddr}" ]; then
    # TODO: some cursory checks to make sure this IP address is valid
    # or maybe rewrite the whole effing thing in python for good measure
    cat << EOF > ${citmpdir}/network-config
---
version: 1
config:
- type: physical
  name: eth0
  subnets:
  - type: static
    address: ${ipaddr}
    gateway: ${gateway}
    dns_nameservers:
      - ${gateway}
    dns_search:
      - xthorsworld.com
EOF
fi

# stuff it in the ciimg
if [ -n "${ipaddr}" ]; then
    mcopy -oi ${ciimg} ${citmpdir}/user-data ${citmpdir}/network-config ${citmpdir}/meta-data ::
else
    mcopy -oi ${ciimg} ${citmpdir}/user-data ${citmpdir}/meta-data ::
fi

# blast citmpdir
rm -rf ${citmpdir}

# boot it up after prepping the image
virt-install --virt-type kvm --name ${vmname} --ram ${memory} --vcpus ${vcpus} --os-variant ${variant} --network=bridge=br0,model=virtio --graphics vnc --disk path=${target_hdd},cache=writeback --disk path=${ciimg} --noautoconsole --import

###
# network interface names:
## ubuntu (focal and bionic): enp1s0
## debian buster: enp1s0 - but even though cloud-init wrote the network config, the instance isn't using it. debug!

# TODO: remove the CI hard drive from the VM after it boots up, otherwise, snapshots don't work