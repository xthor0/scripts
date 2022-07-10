#!/bin/bash

imgpath=/mnt/cloudimg/standard

# usage
function usage() {
        echo "`basename $0`: Prep a QEMU/KVM cloud image using virt-sysprep."
        echo "Usage:

`basename $0` -a <img> [ -u username ] [ -k path/to/id_rsa.pub ] [ -r root_password ]
-u : username [ default: output of whoami ]
-k : path to SSH key you want injected for -u argument [ default: ~/.ssh/authorized_keys ]
-f : flavor OS (needs to exist in ${imgpath} as flavor.qcow2)
-h : hostname to give VM
-r : set root password: if value passed is \"random\" it will be, well, random
"
        exit 255
}

# command-line arguments
while getopts "u:k:f:h:r:" OPTION; do
  case $OPTION in
    u) username="${OPTARG}";;
    k) sshkey="${OPTARG}";;
    f) flavor="${OPTARG}";;
    h) fqdn="${OPTARG}";;
    r) rootpass="${OPTARG}";;
    *) usage;;
  esac
done

### BEGIN
# hostname is only required argument
if [ -z "${fqdn}" ]; then
  usage
fi

if [ -z "${username}" ]; then
  username="$(whoami)"
fi

if [ -z "${sshkey}" ]; then
  sshkey=${HOME}/.ssh/authorized_keys
fi
test -f "${sshkey}"
if [ $? -ne 0 ]; then
  echo "Error: ${sshkey} does not exist."
  exit 255
fi

img="${imgpath}/${flavor}.qcow2"
tgtimg="/var/lib/libvirt/images/${fqdn}.qcow2"
test -f "${img}"
if [ $? -ne 0 ]; then
  echo "Error: qcow2 image ${img} does not exist."
  exit 255
fi

if [ -n "${rootpass} " ]; then
  if [ "${rootpass}" == "random" ]; then
    rootpass_arg="--root-password random"
  else
    rootpass_arg="--root-password password:${rootpass}"
  fi
fi

### prep
# this is just for testing, so a lot of stuff is hard-coded for now
# don't clobber existing defined VM
test -f /etc/libvirt/qemu/${fqdn}.xml
if [ $? -eq 0 ]; then
  echo "Error: VM with name ${fqdn} is already defined -- exiting."
  exit 255
fi

# don't clobber existing disk image
test -f "${tgtimg}"
if [ $? -eq 0 ]; then
  echo "Error: disk image ${tgtimg} already exists -- exiting."
  exit 255
fi

# copy image, rename, resize
echo "Copying ${img} to ${tgtimg}..."
sudo cp "${img}" "${tgtimg}" && sudo qemu-img resize "${tgtimg}" 10G

# create sudoers template - don't change this name without changing the virt-sysprep command...
sudoers_tmp=/tmp/99-virt-sysprep
cat > ${sudoers_tmp} << EOF
# Created by virt-sysprep on ${HOSTNAME} on $(date)

# User rules for ${username}
${username} ALL=(ALL) NOPASSWD:ALL
EOF
chmod 600 ${sudoers_tmp}

netplan_tmp=/tmp/ethernets.yaml
cat > ${netplan_tmp} << EOF
network:
    version: 2
    ethernets:
        zz-all-en:
            match:
                name: "en*"
            dhcp4: true
        zz-all-eth:
            match:
                name: "eth*"
            dhcp4: true
EOF

# virt-sysprep the image
sudo virt-sysprep -a "${tgtimg}" --network --update --selinux-relabel --hostname "${fqdn}" --touch /etc/cloud/cloud-init.disabled \
  ${rootpass_arg} --run-command "useradd -m -p '*' ${username} -s /bin/bash" --ssh-inject ${username}:file:${sshkey} \
  --copy-in ${sudoers_tmp}:/etc/sudoers.d --run-command "chown root:root /etc/sudoers.d/99-virt-sysprep" \
  --run-command 'ssh-keygen -A' --run-command 'test -d /etc/netplan || mkdir /etc/netplan' \
  --copy-in ${netplan_tmp}:/etc/netplan
  # notes...
  # ssh-keygen required, because otherwise Debian will have no SSH host keys
  # netplan yaml required, otherwise there is no network on boot. Should be completely ignored by systems that don't use netplan.
if [ $? -ne 0 ]; then
  echo "Error running virt-sysprep -- exiting."
  exit 255
fi

# remove templated sudoers file
rm ${sudoers_tmp} ${netplan_tmp}

# virt-install
sudo virt-install --virt-type kvm --name ${fqdn} --ram 2048 --vcpus 1 \
	--os-variant linux2016 --network=bridge=br-vlan54,model=virtio --graphics vnc \
	--disk path=${tgtimg},cache=writeback \
	--noautoconsole --import

# fin