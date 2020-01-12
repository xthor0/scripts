#!/bin/bash

# display usage
function usage() {
    echo "`basename $0`: Build Fedora 31 Kickstart ISO."
    echo "Usage:

`basename $0` -k <path to source kickstart> -f <output iso>"
    exit 255
}


iso_src="http://mirrors.xmission.com/fedora/linux/releases/31/Server/x86_64/iso/Fedora-Server-netinst-x86_64-31-1.9.iso"
checksum="http://mirrors.xmission.com/fedora/linux/releases/31/Server/x86_64/iso/Fedora-Server-31-1.9-x86_64-CHECKSUM"

tempdir=${HOME}/tmp/fedora-kickstart

iso_filename=$(basename ${iso_src})

# we need command-line options
while getopts "k:f:v" opt; do
	case $opt in
		k)
			ks=$OPTARG
			;;
		f)
			outfile=$OPTARG
			;;
	esac
done

# validate them
if [ -z "${ks}" -o -z "${outfile}" ]; then
    usage
fi

# make the temp dir if it doesn't exist
test -d "${tempdir}" || mkdir -p ${tempdir}
if [ $? -ne 0 ]; then
    echo "Unable to create ${tempdir} -- exiting."
    exit 255
fi

pushd ${tempdir}
if [ $? -ne 0 ]; then
    echo "Unable to pushd ${tempdir} -- exiting."
    exit 255
fi

# download the ISO if necessary
if [ ! -f ${iso_filename} ]; then
    axel -a ${iso_src}
fi

# verify the ISO
curl ${checksum} | grep ${iso_filename} > ${iso_filename}.sha256
sha256sum -c ${iso_filename}.sha256
if [ $? -ne 0 ]; then
    echo "error - sha256 checksum did not validate correctly."
    exit 255
fi

rm -f ${iso_filename}.sha256

# extract the ISO
7z x -oextract ${iso_filename}
if [ $? -ne 0 ]; then
    echo "error extracting ${iso_filename}."
    exit 255
fi

# get rid of the weird boot directory
rm -rf extract/\[BOOT\]/

# replace grub.cfg for UEFI booting
cat << EOF > extract/EFI/BOOT/grub.cfg
set default="1"

function load_video {
  insmod efi_gop
  insmod efi_uga
  insmod video_bochs
  insmod video_cirrus
  insmod all_video
}

load_video
set gfxpayload=keep
insmod gzio
insmod part_gpt
insmod ext2

set timeout=5
### END /etc/grub.d/00_header ###

search --no-floppy --set=root -l 'Fedora-31-Kickstart'

### BEGIN /etc/grub.d/10_linux ###
menuentry 'Install Fedora 31 via Kickstart' --class fedora --class gnu-linux --class gnu --class os {
	linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-31-Kickstart quiet inst.ks=hd:LABEL=Fedora-31-Kickstart:/ks.cfg
	initrdefi /images/pxeboot/initrd.img
}
EOF
if [ $? -ne 0 ]; then
    echo "error writing extract/EFI/BOOT/grub.cfg"
    exit 255
fi

# modify isolinux.cfg for standard booting
cat << EOF > extract/isolinux/isolinux.cfg
default linux
timeout 200

#display boot.msg
SAY This ISO will DELETE ALL DATA ON THIS MACHINE!!!
SAY It is designed to automatically install Fedora 31
SAY if this isn't what you want to do - power off your machine immediately!!
SAY ==||==||==||==||==
SAY Installation will begin in 20 seconds...

label linux
  menu label ^Install Fedora 31 via Kickstart
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=Fedora-31-Kickstart quiet inst.ks=hd:LABEL=Fedora-31-Kickstart:/ks.cfg
EOF
if [ $? -ne 0 ]; then
    echo "error writing extract/isolinux/isolinux.cfg"
    exit 255
fi

# copy in the kickstart file
cp "${ks}" extract/ks.cfg
if [ $? -ne 0 ]; then
    echo "error copying kickstart file ${ks}. Exiting."
    exit 255
fi

# make the ISO
mkisofs -o ${outfile} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V Fedora-31-Kickstart -boot-load-size 4 -boot-info-table -R -J -v -T extract
if [ $? -ne 0 ]; then
    echo "error running mkisofs, exiting."
    exit 255
fi

# add efi
isohybrid ${outfile}
if [ $? -ne 0 ]; then
    echo "error running isohybrid."
    exit 255
fi

# hoping this allows me to overwrite the ISO after libvirt chown's it
chmod 666 ${outfile}
ls -l ${outfile}

# clean up
rm -rf extract

# create a VM and boot to it - this will fail if one already exists
virt-install --virt-type=kvm --name fedora-31-kickstart --ram 2048 --vcpus 2 --os-variant=fedora31 --network=bridge=virbr0,model=virtio --graphics vnc --disk path=${HOME}/vms/fedora-31-kickstart.qcow2,cache=writeback,size=20 --cdrom ${outfile} --noautoconsole

exit 0