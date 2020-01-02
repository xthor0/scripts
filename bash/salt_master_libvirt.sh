#!/bin/bash

# variable locations for images this script needs
nocloud_img=/home/xthor/vms/salt-nocloud.img
os_img=/home/xthor/vms/salt-os.qcow2
src_img=/storage/cloudimage/CentOS-7-x86_64-GenericCloud-1907.img

# make sure we don't already have this running
virsh destroy salt-master
virsh undefine --remove-all-storage salt-master

# create the nocloud image and populate metadata
dd if=/dev/zero of=${nocloud_img} count=1 bs=1M && mkfs.vfat -n cidata ${nocloud_img}
if [ $? -ne 0 ]; then
    echo "Error - unable to create salt-nocloud.img."
    exit 255
fi

# make a temp dir for the metadata
TEMP_D=$(mktemp -d)
if [ $? -ne 0 ]; then
    echo "Unable to create temp directory -- exiting."
    exit 255
fi

# write out cidata to files
cat > ${TEMP_D}/meta-data << EOF
instance-id: 1
local-hostname: salt.laptop.lab
EOF

# we'll check retval later, but we only set it if non-zero
[ $? -ne 0 ] && retval=$?

# if you change the metadata - make sure you escape the dollar signs!
cat > ${TEMP_D}/user-data << EOF
#cloud-config
users:
  - name: xthor
    passwd: \$6\$Og9AInwoEYIew7ZM\$HCaWJyipauykgO1ZHP4/6y.r6aTpg0xHKX/LYWKnL5k1gQK4I3J75LEFj6a5yu31.GAceO9ORyNy.lnbe2MZL.
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
timezone: America/Denver
yum_repos:
  salt-latest:
    baseurl: https://repo.saltstack.com/yum/redhat/7/\$basearch/latest
    enabled: true
    failovermethod: priority
    gpgcheck: true
    gpgkey: https://repo.saltstack.com/py3/redhat/7/x86_64/latest/SALTSTACK-GPG-KEY.pub
    name: SaltStack Latest Release Channel for RHEL/Centos \$releasever
packages:
  - epel-release
  - salt-master
  - salt-ssh
  - vim-enhanced
  - bash-completion
  - wget
  - rsync
  - deltarpm
package_upgrade: true
power_state:
  delay: now
  mode: reboot
  message: Rebooting for updates
  condition: True
runcmd:
  - touch /etc/cloud/cloud-init.disabled
  - mkdir -p /srv/salt/reactor /srv/salt/top /srv/salt/states /srv/salt/pillar /srv/salt/reactor
  - systemctl enable salt-master
  - 'curl https://raw.githubusercontent.com/xthor0/scripts/libvirt/bash/salt-master-local-lab.sh | bash'
mounts:
  - ["gateway:/home/xthor/git/salt-top", "/srv/salt/states", "nfs", ""]
EOF
[ $? -ne 0 ] && retval=$?

cat > ${TEMP_D}/network-config << EOF
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
    address: 192.168.124.10/24
    gateway: 192.168.124.1
    dns_nameservers:
      - 192.168.124.1
    dns_search:
      - laptop.lab
EOF
[ $? -ne 0 ] && retval=$?

if [ -n "${retval}" ]; then
    echo "Error writing meta-data to files. Exiting!"
    exit 255
fi

# write ci image
mcopy -i ${nocloud_img} ${TEMP_D}/user-data :: && mcopy -i ${nocloud_img} ${TEMP_D}/meta-data :: && mcopy -i ${nocloud_img} ${TEMP_D}/network-config ::
if [ $? -ne 0 ]; then
    echo "mcopy to ${nocloud_img} failed! exiting."
    exit 255
fi

# copy OS image
cp ${src_img} ${os_img} && virt-install --virt-type=kvm --name salt-master --ram 2048 --vcpus 2 --os-variant=centos7.0 --network=bridge=virbr0,model=virtio --graphics vnc --disk path=${os_img},cache=writeback --import --disk path=${nocloud_img},cache=none --noautoconsole
if [ $? -eq 0 ]; then
    echo "Salt master booting now!"
else
    echo "We ran into a problem - consult the output above."
    exit 255
fi

# cleanup temp dir
rm -rf ${TEMP_D}

exit 0