#!/usr/bin/env bash

[ -z "${1}" ] && {
  echo "You must specify the name of a VM to build. Exiting."
  exit 255
}

# hard coding these for now
VBOX_DIR="~/VirtualBox\ VMs"
cpu=1
memory=1024
vmname="${1}"
storage="8192"
image="~/cloudimage/centos7-1907.vdi"
vbm="/usr/local/bin/VBoxManage"

# my idea was to wrap all the commands in an array, and then iterate through
cmdlist=()
cmdlist=(
    "${vbm} createvm --name ${vmname} --ostype Linux_64 --register"
    "${vbm} modifyvm ${vmname} --memory ${memory} --cpus ${cpu} --uart1 0x03f8 4 --uartmode1 disconnected --nic1 hostonly --hostonlyadapter1 vboxnet0"
    "${vbm} clonemedium disk ${image} ${VBOX_DIR}/${vmname}/${vmname}.vdi"
    "${vbm} modifymedium disk ${VBOX_DIR}/${vmname}/${vmname}.vdi --resize ${storage}"
    "${vbm} storagectl ${vmname} --name sata_c1 --add sata --controller IntelAhci --portcount 2"
    "${vbm} storageattach ${vmname} --storagectl sata_c1 --port 0 --device 0 --type hdd --medium ${VBOX_DIR}/${vmname}/${vmname}.vdi"
    "${vbm} setextradata ${vmname} \"VBoxInternal/Devices/pcbios/0/Config/DmiSystemSerial\" \"ds=nocloud-net;s=http://10.187.88.1/${vmname}/\""
)

# build the VM
IFS=""
for cmd in ${cmdlist[*]}; do
    eval ${cmd}
    if [ $? -ne 0 ]; then
        echo "Command exited with non-zero status."
        echo "Command: "
        echo "${cmd}"
        exit 255
    fi
done

# create the metadata so cloud-init can grab it
ssh lab-router.lab "/root/cloudinit-metadata.sh ${vmname}"
if [ $? -ne 0 ]; then
  echo "error creating metadata on lab-router.lab -- exiting."
fi

# boot up the VM
${vbm} startvm ${vmname} --type headless
if [ $? -ne 0 ]; then
  echo "Error booting up VM ${vmname} -- exiting."
fi

# get the MAC address of the VM we just created
# we can't use ${VBOX_DIR} here because `eval` strips out the \... sigh
if [ -f ~/Library/VirtualBox/VirtualBox.xml ]; then
  eval $(grep defaultMachineFolder ~/Library/VirtualBox/VirtualBox.xml | awk '{ print $2 " " $3 }')
fi

vboxfile="${defaultMachineFolder}/${vmname}/${vmname}.vbox"
test -f ${vboxfile}
if [ $? -eq 0 ]; then
  macaddr=$(grep MACAddress ${vboxfile} | awk '{ print $4 }' | cut -d \= -f 2 | tr -d \" | sed 's/.\{2\}/&:/g' | sed 's/:$//g' | tr [:upper:] [:lower:])
  echo "MAC address of ${vmname}: ${macaddr}"
else
  echo "Unable to determine MAC address of ${vmname}."
  exit 255
fi

# make sure the VM boots up and spit out the IP of the VM
maxattempts=120
attempts=0
echo "Waiting for VM ${vmname} to boot..."
while [ ${attempts} -lt ${maxattempts} ]; do
  ssh lab-router.lab "grep dnsmasq-dhcp /var/log/messages | tail -n1 | grep -q ${macaddr}"
  if [ $? -eq 0 ]; then
    echo "VM has booted! IP address: "
    ssh lab-router.lab "grep dnsmasq-dhcp.*DHCPACK.*${macaddr} /var/log/messages | awk '{ print \$8 }'"
    break
  else
    if [ ${attempts} -lt ${maxattempts} ]; then
      let attempts+=1
      sleep 2
    else
      echo "Max attempts reached! VM did not boot, you should investigate!"
      break
    fi
  fi
done

exit 0
