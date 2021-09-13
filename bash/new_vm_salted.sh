#!/bin/bash

image_dir=${HOME}/tmp/cloud-images
target_dir=/var/lib/libvirt/images

# display usage
function usage() {
	echo "`basename $0`: Build a salted VM from a cloud image"
	echo "Usage:

`basename $0` -f <flavor> -n <FQDN of VM> [ -c <VCPUs> -r <RAM in GB> -s <storage in GB> ]"
	exit 255
}

function bad_taste() {
    echo "Sorry, I don't know what flavor of Linux ${flavor} is."
    exit 255
}

# default options
flavor="debian11"
ram=2
vcpus=1
storage=10

# get command-line args
while getopts "f:n:c:r:s:" OPTION; do
	case $OPTION in
		f) flavor="$OPTARG";;
		n) vmname="$OPTARG";;
        c) vcpus="$OPTARG";;
        r) ram="$OPTARG";;
        s) storage="$OPTARG";;
		*) usage;;
	esac
done

# validate - we need at least a flavor and a VM name
if [ -z "${vmname}" ]; then
    usage
fi

# RAM is tricky, don't let me be stupid and specify more RAM than I have. Capping out at 16.
if [ "${ram}" -gt 16 ]; then
    echo "Um, no, you can't have more than 16GB RAM."
    usage
else
    memory=$((${ram} * 1024))
fi

# image prep notes
# cd ${image_dir}
# cp generic-image.qcow2 salted-image.qcow2 # do I really need to tell you to swap out the names, dumbass?
# sudo virt-sysprep -a salted-image.qcow2 --selinux-relabel --install curl --run-command "curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh && bash /tmp/install_salt.sh -P -X -j '{ \"hash_type\": \"sha256\", \"log_level\": \"info\", \"master\": \"192.168.122.10\" }'" --network

# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="${image_dir}/bionic-salted-qmd64.qcow2"; variant="ubuntu18.04";;
    focal) image="${image_dir}/focal-salted-amd64.qcow2"; variant="ubuntu20.04";;
    centos7) image="${image_dir}/centos-7-salted-x86_64.qcow2"; variant="centos7.0";;
    almalinux8) image="${image_dir}/almalinux-8-salted-x86_64.qcow2"; variant="centos8";;
    debian10) image="${image_dir}/debian-10-salted-amd64.qcow2"; variant="debian10";;
    debian11) image="${image_dir}/debian-11-salted-amd64.qcow2"; variant="debian10";;
    *) bad_taste;;
esac

# make sure we're not clobbering a running domain - that'd be bad
target_hdd="${target_dir}/${vmname}.qcow2"
if [ -f ${target_hdd} ]; then
    echo "${target_hdd} already exists - exiting."
    exit 255
fi

test -f /etc/libvirt/qemu/${vmname}.xml
if [ $? -eq 0 ]; then
    echo "${vmname} is already a defined domain -- exiting."
    exit 255
fi

# copy image to libvirt dir
target_img=${target_dir}/${vmname}.qcow2
sudo cp ${image} ${target_img}

# qemu-img resize
sudo qemu-img resize ${target_img} ${storage}G

# virt-sysprep - set hostname, root password, inject SSH keys
# it kinda sucks we have to do this for focal, alone, but... without it, we get no networking :man_shrugging:
if [ "${flavor}" == "focal" ]; then
    focal_sysprep_opts="--copy-in /tmp/01-netplan.yaml:/etc/netplan/"
    cat > /tmp/01-netplan.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: true
EOF
fi

sudo virt-sysprep -a ${target_img} --hostname ${vmname} --selinux-relabel --ssh-inject root:file:/home/xthor/.ssh/id_rsa.pub --root-password password:toor --run-command 'ssh-keygen -A' ${focal_sysprep_opts}
if [ $? -ne 0 ]; then
    echo "Error running virt-sysprep -- exiting."
    exit 255
fi

if [ "${flavor}" == "focal" ]; then
    rm -f /tmp/01-netplan.yaml
fi

# virt-install with all the above options!
virt-install --virt-type kvm --name ${vmname} --ram ${memory} --vcpus ${vcpus} --os-variant ${variant} --graphics spice --disk path=${target_img},cache=writeback --noautoconsole --import