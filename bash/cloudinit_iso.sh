#!/bin/bash

# display usage
function usage() {
    echo "`basename $0`: Create a CloudInit ISO"
    echo "Usage:

`basename $0` -n <name of VM> [ -i <static IP> ]"
    exit 255
}

# get command-line args
while getopts "n:i:" OPTION; do
    case $OPTION in
        n) vmname="$OPTARG";;
        i) ipaddr="$OPTARG";;
        *) usage;;
    esac
done

# make sure we got an argument
if [ -z "${vmname}" ]; then
  usage
fi

gateway=10.200.106.1

# http root
docroot=/var/www/lighttpd/ci
cidata="${docroot}/${vmname}"

# create dir for ci data
mkdir ${cidata}
if [ $? -ne 0 ]; then
  echo "error creating ${vmname} dir in ${docroot} -- exiting."
  exit 255
fi

if [ -n "${ipaddr}" ]; then
  cat << EOF > ${cidata}/meta-data
instance-id: 1
local-hostname: ${vmname}.xthorsworld.com

EOF
else
  # meta-data is where the hostname gets set
  cat << EOF > ${cidata}/meta-data
instance-id: 1
local-hostname: ${vmname}.xthorsworld.com
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
EOF
fi
if [ $? -ne 0 ]; then
    echo "Error writing ${cidata}/meta-data -- exiting."
    exit 255
fi


# password is: toor
cat << EOF > ${cidata}/user-data
#cloud-config
users:
  - name: root
    passwd: \$6\$j35iy5ZDq4422YhB\$CYiwq.LiFa0lnemUDVcZ0oG24imSk8NKTZMabZ67dUpiAbSQVij7yHbDwpY937TT5X1fzcVzdjwAgxby2XS5X/
    lock_passwd: false
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
timezone: America/Denver
runcmd:
    - touch /etc/cloud/cloud-init.disabled
EOF
if [ $? -ne 0 ]; then
    echo "Error writing ${cidata}/user-data -- exiting."
    exit 255
fi

# make sure the VM doesn't already exist (though, it should have died earlier when creating the cidata dir)
virsh list --all --name | grep -qw ${vmname}
if [ $? -eq 0 ]; then
  echo "A VM named ${vmname} already exists! Exiting."
  exit 255
fi

# build the vm
virt-install --virt-type=kvm --name ${vmname} --ram 2048 --vcpus 1 --os-variant=rhel-atomic-7.4 --network=bridge=br-vlan06,model=virtio --graphics vnc --disk /var/lib/libvirt/images/${vmname}.qcow2c,cache=writeback --import --noautoconsole --sysinfo smbios,type=1,serial=ds=nocloud-net;s=http://10.200.106.12/${vmname}/
