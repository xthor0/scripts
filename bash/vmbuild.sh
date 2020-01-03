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
while getopts "n:i:f:s:c:r:t" OPTION; do
    case $OPTION in
        n) vmname="$OPTARG";;
        f) flavor="$OPTARG";;
        s) storage="$OPTARG";;
        c) cpu="$OPTARG";;
        r) ram="$OPTARG";;
        i) ipaddr="$OPTARG";;
        t) salt="true";;
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

vmdir=${HOME}/vms
# turn the flavor variable into a location for images
case ${flavor} in
    bionic) image="${vmdir}/cloudimage/prep/bionic-server-cloudimg-amd64.img"; variant="ubuntu18.04";;
    centos7) image="${vmdir}/cloudimage/prep/CentOS-7-x86_64-GenericCloud.qcow2"; variant="centos7.0";;
    centos-atomic7) image="${vmdir}/cloudimage/CentOS-Atomic-Host-7.1910-GenericCloud.qcow2"; variant="centos7.0";;
    debian10) image="${vmdir}/cloudimage/prep/debian-10-openstack-amd64.qcow2"; variant="debian10";;
    debian9) image="${vmdir}/cloudimage/prep/debian-9-openstack-amd64.qcow2"; variant="debian9";;
    *) bad_taste;;
esac

# target image
HDD_IMG="${vmdir}/${vmname}-os.qcow2"

# make sure we're not clobbering something that's already running
test -f ${HDD_IMG}
if [ $? -eq 0 ]; then
    echo "${HDD_IMG} already exists - exiting."
    exit 255
fi

# copy the source image to the destination
cp "${image}" ${HDD_IMG}
if [ $? -ne 0 ]; then
    echo "Error copying ${image} to ${HDD_IMG}. Exiting!"
    exit 255
fi

# static IPs don't work yet, but there has to be a way with virt-sysprep, or something
if [ -n "${ipaddr}" ]; then
    echo "Static IPs don't work yet. Come back tomorrow."
fi

# TODO: make this cmdline modular

if [ -z "${salt}" ]; then
    virt-sysprep -a ${HDD_IMG} --hostname ${vmname}.laptop.lab --ssh-inject root --root-password password:toor --selinux-relabel
else
    virt-sysprep -a ${HDD_IMG} --hostname ${vmname}.laptop.lab --install curl --selinux-relabel --ssh-inject root --root-password password:toor --run-command 'curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh && bash /tmp/install_salt.sh -P -X' --network
fi

if [ $? -ne 0 ]; then
    echo "virt-sysprep exited with a non-zero status."
    exit 255
fi

# deploy the VM
virt-install --virt-type=kvm --name ${vmname} --ram ${memory} --vcpus ${cpu} --os-variant=${variant} --network=bridge=virbr0,model=virtio --graphics vnc --disk path=${HDD_IMG},cache=writeback --import --noautoconsole

# done, I think :)
exit 0
