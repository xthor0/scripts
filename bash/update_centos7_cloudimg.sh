#!/bin/bash

echo "Don't use this. Read the file. Bye."
exit 255

# oh. my. god.
# this is all so horribly, horribly unnecessary.

# why?

# virt-sysprep -a CentOS-7-x86_64-GenericCloud-test.qcow2 --update --network

# lol
# double shit.
# I'll bet I don't need anything more than the god-damned meta-data (to set the hostname) if I use this command:

# virt-sysprep -a CentOS-7-x86_64-GenericCloud-test.qcow2 --update --network --mkdir /root/.ssh --copy-in ~/.ssh/id_rsa.pub /root/.ssh/authorized_keys --root-password toor --selinux-relabel

# holy facepalm, I've been doing *ALL* of this wrong.

# my OS onboarding will look like this:

1. download the cloud image
2. use `virt-sysprep -a original_cloud_image.qcow2 --touch /etc/cloud/cloud-init.disabled --update --network --selinux-relabel` to prep the image with available updates
3. copy the image to the OS name I want to use (i.e. `~/vms/centos7.qcow2`)
4. use `virt-sysprep` to set the hostname: `virt-sysprep -a ~/vms/centos7.qcow2 --hostname cent7updated.laptop.lab -ssh-inject root --root-password password:toor --selinux-relabel`
5. use `virt-install` to create a VM and boot it up

for salt minions:

virt-sysprep -a ~/vms/c7salt-os.qcow2 --hostname c7salt.laptop.lab --selinux-relabel -ssh-inject root --root-password password:toor --run-command 'curl -L https://bootstrap.saltstack.com -o /tmp/install_salt.sh && bash /tmp/install_salt.sh -P -X' --network

# won't work on deb10 boxes right now, but should work on everything else. In fact, let's try debian 9...

# tell me that isn't simpler than what I've been working on!

# the rest of this, it's just here for posterity.
vmdir=${HOME}/vms
vmname="cent7update"

memory=1024
cpu=1
image="/storage/cloudimage/CentOS-7-x86_64-GenericCloud.qcow2"
variant="centos7.0"

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

# password is: toor
cat << EOF > ${TEMP_D}/user-data
#cloud-config
users:
  - name: root
    passwd: \$6\$j35iy5ZDq4422YhB\$CYiwq.LiFa0lnemUDVcZ0oG24imSk8NKTZMabZ67dUpiAbSQVij7yHbDwpY937TT5X1fzcVzdjwAgxby2XS5X/
    lock_passwd: false
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
timezone: America/Denver
package_upgrade: true
power_state:
    mode: poweroff
    condition: True
runcmd:
    - touch /etc/cloud/cloud-init.disabled
EOF
if [ $? -ne 0 ]; then
    echo "Error writing ${TEMP_D}/user-data -- exiting."
    exit 255
fi

# write the config files to the vfat image
mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/meta-data :: && mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/user-data ::
if [ $? -ne 0 ]; then
  echo "Error writing cidata to cloudinit.img."
  exit 255
fi

# deploy the VM
virt-install --virt-type=kvm --name ${vmname} --ram ${memory} --vcpus ${cpu} --os-variant=${variant} --network=bridge=virbr0,model=virtio --graphics vnc --disk path=${HDD_IMG},cache=writeback --import --disk path=${CLOUDINIT_IMG},cache=none --noautoconsole

# wait while the updates install
while true; do
    virsh list | grep -qw ${vmname}
    if [ $? -eq 0 ]; then
        echo "Still running..."
        sleep 10
    else
        echo "Done!"
        break
    fi
done

# clone the server (so we can make sure updates applied and keep the old one around for logging)
clonevm="centos7updates-clone"
virt-clone --original ${clonevm} --name centos7new --file ${vmdir}/${clonevm}-os.qcow2 --skip-copy=vdb

# remove vdb from the clone
virsh detach-disk --domain ${clonevm} --target vdb --config

# sysprep the image
virt-sysprep -d ${clonevm} --operation defaults,user-account --selinux-relabel
if [ $? -ne 0 ]; then
    echo "Error running virt-sysprep. Exiting."
    exit 255
fi

# grab the disk path to vda
source_img="$(virsh domblklist --domain ${clonevm} | grep vda | awk '{ print $2 }')"

# set vars for the new VM
vmname=c7upd
CLOUDINIT_IMG=${vmdir}/${vmname}-cidata.img
HDD_IMG=${vmdir}/${vmname}-os.img

# clone the hard drive of the source VM
cp ${source_img} ${HDD_IMG}
if [ $? -ne 0 ]; then
    echo "Error - unable to copy ${source_img} to ${HDD_IMG}. Exiting."
    exit 255
fi

# build a new ci image
dd if=/dev/zero of=${CLOUDINIT_IMG} count=1 bs=1M && mkfs.vfat -n cidata ${CLOUDINIT_IMG}
if [ $? -ne 0 ]; then
  echo "error creating ${CLOUDINIT_IMG} -- exiting."
  exit 255
fi

# new meta-data because we have a new hostname
cat << EOF > ${TEMP_D}/meta-data
instance-id: 1
local-hostname: ${vmname}.laptop.lab
EOF

# exactly the same settings as before - only, this time, without updates and auto shutdown
cat << EOF > ${TEMP_D}/user-data
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
    echo "Error writing ${TEMP_D}/user-data -- exiting."
    exit 255
fi

# write the config files to the vfat image
mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/meta-data :: && mcopy -i ${CLOUDINIT_IMG} ${TEMP_D}/user-data ::
if [ $? -ne 0 ]; then
  echo "Error writing cidata to ${CLOUDINIT_IMG}."
  exit 255
fi

# we can clean up the temp dir now
rm -rf "${TEMP_D}"

# build another VM
virt-install --virt-type=kvm --name ${vmname} --ram ${memory} --vcpus ${cpu} --os-variant=${variant} --network=bridge=virbr0,model=virtio --graphics vnc --disk path=${HDD_IMG},cache=writeback --import --disk path=${CLOUDINIT_IMG},cache=none --noautoconsole

# done, I think :)
exit 0
