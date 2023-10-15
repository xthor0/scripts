#!/bin/bash

# immediately exit on any error
set -e

# get the next vmID (non template, for now)
highest_id=$(qm list | awk '{ print $1 }' | grep -v ^VMID | grep -v ^9[0-9][0-9][0-9] | sort -n | tail -n1)

# here's our ID
vm_id=$((highest_id+1))

# create the VM
qm create ${vm_id} --name test-vm-${vm_id}.xthorsworld.lab --memory 2048 --net0 virtio,bridge=vmbr0,tag=54

# import the debian 12 qcow2 disk to VM created
qm importdisk ${vm_id} jammy-server-cloudimg-amd64.img local-lvm

# attach disk
qm set ${vm_id} --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-${vm_id}-disk-0

# create ide for cloudinit
qm set ${vm_id} --ide2 local-lvm:cloudinit

# adjust boot settings, otherwise... won't work
qm set ${vm_id} --boot c --bootdisk scsi0
qm set ${vm_id} --serial0 socket --vga serial0
qm set ${vm_id} --ipconfig0 ip=dhcp

# make the template disk 10G instead of 2G
qm resize ${vm_id} scsi0 10G

# set up some basic cloud-init parameters
qm set ${vm_id} --cicustom "user=local:snippets/ci-custom.yaml"

# done
exit 0