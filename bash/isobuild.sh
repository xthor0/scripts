#!/bin/bash

# variables
source="http://mirror.facebook.net/centos/7"
shatxt="${source}/isos/x86_64/sha256sum.txt"
build="$HOME/isobuild"
shaname=$(basename ${shatxt})

# we need command-line options
while getopts "k:f:v" opt; do
	case $opt in
		k)
			ks=$OPTARG
			;;
		f)
			outfile=$OPTARG
			;;
		v)
			vnc="yes";;
	esac
done

# validate arguments...
if [ -z "$ks" ]; then
	echo "You must specify the location of a kickstart file with the -k option!"
	exit 255
fi

if [ -z "$outfile" ]; then
	echo "You must specify the base output file name with -f"
	echo "example: $(basename $0) -f pl-ks -- output file: pl-ks-$(date +%Y%m%d).iso"
	exit 255
fi

# name of output file
isobuild="${outfile}-$(date +%Y%m%d).iso"

# make sure we have createrepo and mkisofs before we start
if [ ! -f "$(which mkisofs)" ]; then
	echo "Missing mkisofs - please install it."
	exit 255
fi

if [ ! -f "$(which createrepo)" ]; then
	echo "Missing createrepo - please install it."
	exit 255
fi

### BEGIN ###>>
pushd ${build}
if [ $? -ne 0 ]; then
	echo "Error, does ${build} exist as a directory?"
	exit 255
fi

# make sure the kickstart file that is specified exists
if [ -f "${ks}" ]; then
	echo "Using kickstart file: $ks"
else
	echo "Unable to find specified kickstart file: ${ks}"
	echo "Make sure you specified a fully-qualified path!"
	exit 255
fi

# if we're doing a KS VNC install, we need to make sure that it doesn't say 'text' in the ks file
if [ -n "$vnc" ]; then
	head ${ks} | grep -q ^text
	if [ $? -eq 0 ]; then
		echo "Error: Your kickstart file specifies a text-mode installation."
		echo "You can't use that with a VNC installation!"
		exit 255
	fi
fi

# retrieve hash
test -f ${shaname} && rm -f ${shaname}
wget ${shatxt}
if [ $? -eq 0 ]; then
	# this will ALWAYS download the latest ISO - so, we need to derive what that is from the hash file
	isoname=$(cat ${shaname} | grep Minimal | awk '{ print $2 }')
	if [ -f "${isoname}" ]; then
		echo "ISO has already been downloaded..."
	else
		iso=${source}/isos/x86_64/${isoname}
		wget ${iso}
	fi
else
	echo "Error downloading shasum txt file, exiting."
	exit 255
fi

# validate ISO
cat ${shaname} | grep ${isoname} > validate.txt
sha256sum -c validate.txt
if [ $? -eq 1 ]; then
	echo "Error - sha256sum of ${isoname} did not validate. Exiting."
	exit 255
else
	rm validate.txt
fi

# can we sudo?
echo "You're going to need sudo rights to run this, for several reasons."
echo "1: We have to install the salt-repo-latest package, so we can spin that into the ISO"
echo "2: For some dumb reason, yum won't allow --downloadonly unless you run it as root"
echo "Stupid, I know."
echo
echo "Please enter your sudo password when prompted (running 'sudo whoami' to test:)"
echo
sudo whoami

# extract ISO
7z x -oextract ${isoname}

# inject ks.cfg
cp ${ks} extract/ks.cfg
if [ $? -ne 0 ]; then
	echo "Error copying ${ks} to the ISO directory!"
	echo "Cannot build ISO!"
	exit 255
fi

# modify isolinux.cfg to reflect single ks boot source
cat << EOF > extract/isolinux/isolinux.cfg
default linux
timeout 200

#display boot.msg
SAY This ISO will DELETE ALL DATA ON THIS MACHINE!!!
SAY It is designed to automatically install CentOS 7
SAY if this isn't what you want to do - power off your machine immediately!!
SAY ==||==||==||==||==
SAY Installation will begin in 20 seconds...

label linux
  menu label ^Install CentOS Linux 7
  kernel vmlinuz
EOF

# we also have to do this to the grub.cfg if we're booting UEFI
cat << EOF > extract/EFI/BOOT/grub.cfg
set default="1"
set timeout=20

menuentry 'CentOS 7 Will Automatically Install in 20 seconds' --class fedora --class gnu-linux --class gnu --class os {
EOF

# append installation options if we want VNC
if [ -n "$vnc" ]; then
	echo "append initrd=initrd.img inst.stage2=hd:LABEL=CentOS-7-KSInst quiet inst.ks=hd:LABEL=CentOS-7-KSInst:/ks.cfg inst.vnc inst.vncpassword=r0ck0n netwait=60" >> extract/isolinux/isolinux.cfg
	echo "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=CentOS-7-KSInst quiet inst.ks=hd:LABEL=CentOS-7-KSInst:/ks.cfg inst.vnc inst.vncpassword=r0ck0n netwait=60" >> extract/EFI/BOOT/grub.cfg
else
	echo "append initrd=initrd.img inst.stage2=hd:LABEL=CentOS-7-KSInst quiet inst.ks=hd:LABEL=CentOS-7-KSInst:/ks.cfg netwait=60" >> extract/isolinux/isolinux.cfg
	echo "linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=CentOS-7-KSInst quiet inst.ks=hd:LABEL=CentOS-7-KSInst:/ks.cfg netwait=60" >> extract/EFI/BOOT/grub.cfg
fi

# close out grub.cfg for UEFI
cat << EOF >> extract/EFI/BOOT/grub.cfg
initrdefi /images/pxeboot/initrd.img
}
EOF

# moving into extract dir
pushd extract

# this is a bit of a oneoff, but if this system is going to have salt-repo-latest, we'll have to
# install that directly, because we can't get that from yum install.
grep -q salt-repo-latest $ks
if [ $? -eq 0 ]; then
	wget https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm
	if [ $? -eq 0 ]; then
		mv salt-repo-latest-2.el7.noarch.rpm Packages
		if [ $? -ne 0 ]; then
			echo "WTF? Error moving the salt-repo-latest RPM to the Packages directory."
			echo "Check the output and see why."
			exit 255
		fi
	else
		echo "Error downloading salt-repo-latest package - check the output."
		exit 255
	fi
fi

# let's get a list from the kickstart file of all the packages that need to be installed
pkglist="$(grep -A100 '^%packages' $ks | grep -B100 -m1 '^%end' | grep -v '^[-@#%]' | tr \\n ' ')"

# download some needed packages
# if you change the packages installed in the kickstart file, they'd better be here!
# the 'updates' repo gets disabled - otherwise, it pulls in newer files of existing RPMs, which breaks
sudo yum install --disablerepo=updates --installroot=/tmp --releasever=/ --downloadonly --downloaddir=Packages $pkglist
if [ $? -ne 0 ]; then
	echo "Error while downloading packages with Yum - check output."
	exit 255
else
	sudo chown -R $USER Packages
fi

# before we createrepo - we need to make sure all our packages will install
# make sure you use a fully-qualified path, or rpm tries to put this in /... ugh
rpm --initdb --dbpath ${build}/rpmtmp
rpm --test --dbpath ${build}/rpmtmp -ivh Packages/*.rpm
if [ $? -ne 0 ]; then
	echo "Error resolving dependencies! Fix your isobuild script!"
	exit 255
else
	rm -rf ${build}/rpmtmp
fi

# we're trying to find the comps.xml file, which is in some weird naming format
for file in repodata/*; do
	zcat $file | head | grep -q '^<comps>'
	if [ $? -eq 0 ]; then
		zcat $file > comps.xml && rm -rf repodata
	fi
done

# build the repo
if [ -f comps.xml ]; then
	createrepo -g comps.xml .
	if [ $? -ne 0 ]; then
		echo "error running createrepo - please check output."
		exit 255
	fi
else
	echo "Error! Unable to find comps.xml on this ISO - exiting."
	exit 255
fi

# get rid of the [BOOT] directory
rm -rf \[BOOT\]

# build the ISO
mkisofs -o ../${isobuild} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V CentOS-7-KSInst -boot-load-size 4 -boot-info-table -R -J -v -T ../extract
if [ $? -ne 0 ]; then
	echo "Error running mkisofs -- please check output."
	exit 255
fi

# back a directory
popd

# remove extract directory only if mkisofs is happy
if [ $? -eq 0 ]; then
	rm -rf extract
fi

# done - we only leave the ISO and the shasum files
popd

echo "Done!"
echo "Built ISO file: ${isobuild}"

exit 0
