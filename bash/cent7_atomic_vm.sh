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

# image sources
srcimg=/home/xthor/cloudimage/CentOS-Atomic-Host-7.1910-GenericCloud.qcow2
dstimg=/var/lib/libvirt/images/${vmname}.qcow2
ciimg=/var/lib/libvirt/images/${vmname}-ci.qcow2

# http root
#docroot=/var/www/lighttpd/ci
#cidata="${docroot}/${vmname}"

# clone the image
if [ -f ${dstimg} ]; then
  echo "${dstimg} already exists. Exiting."
  exit 255
fi

echo "Copying ${srcimg} to ${dstimg}..."
cp ${srcimg} ${dstimg}
if [ $? -eq 0 ]; then
  echo "Adding 10G to ${dstimg}..."
  qemu-img resize ${dstimg} +10G
  if [ $? -ne 0 ]; then
    echo "Error resizing ${dstimg} -- exiting."
    exit 255
  fi
else
  echo "Error copying ${srcimg} to ${dstimg} -- exiting."
  exit 255
fi

# create dir for ci data
#mkdir ${cidata}
cidata=$(mktemp -d)
if [ $? -ne 0 ]; then
  echo "error creating ${vmname} dir in ${docroot} -- exiting."
  exit 255
fi

cat << EOF > ${cidata}/meta-data
instance-id: 1
local-hostname: ${vmname}.xthorsworld.com
EOF
if [ $? -ne 0 ]; then
    echo "Error writing ${cidata}/meta-data -- exiting."
    exit 255
fi

# network-config is only necessary if we're setting a static IP address
if [ -n "${ipaddr}" ]; then
  cat << EOF > ${cidata}/network-config
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
EOF
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

# make the disk for ci data
truncate --size 2M ${ciimg}
mkfs.vfat -n cidata ${ciimg}
mcopy -oi ${ciimg} ${cidata}/user-data ${cidata}/meta-data ::

if [ -n "${ipaddr}" ]; then
  mcopy -oi ${ciimg} ${cidata}/network-config ::
fi

# make sure the VM doesn't already exist (though, it should have died earlier when creating the cidata dir)
virsh list --all --name | grep -qw ${vmname}
if [ $? -eq 0 ]; then
  echo "A VM named ${vmname} already exists! Exiting."
  exit 255
fi

# build the vm
virt-install --virt-type=kvm --name ${vmname} --ram 2048 --vcpus 1 --os-variant=rhel-atomic-7.4 --network=bridge=br-vlan06,model=virtio --graphics vnc --disk ${dstimg},cache=writeback --disk=${ciimg} --import --noautoconsole

# kill the temp dir
rm -rf ${cidata}

# end
