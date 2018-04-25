#!/bin/bash

# variables
source="http://mirror.facebook.net/centos/7.4.1708/"
shatxt="${source}/isos/x86_64/sha256sum.txt"
iso="${source}/isos/x86_64/CentOS-7-x86_64-NetInstall-1708.iso"
build="$HOME/isobuild"
isoname=$(basename ${iso})
shaname=$(basename ${shatxt})
isooutput="cent7salt-$(date +%Y%m%d).iso"

# we need command-line options
while getopts "k:" opt; do
	case $opt in
		k)
			ks=$OPTARG
			;;
	esac
done

if [ -z "$ks" ]; then
	echo "Error - you must specify the -k option!"
	echo "-k /path/to/kickstart.file"
	exit 255
fi
echo "Using kickstart file: $ks"

### BEGIN ###>>
pushd ${build}
if [ $? -ne 0 ]; then
	echo "Error, does ${build} exist as a directory?"
	exit 255
fi

# retrieve hash
test -f ${shaname} || wget ${shatxt}
if [ $? -eq 0 ]; then
	# get iso, too
	if [ -f "${isoname}" ]; then
		echo "ISO has already been downloaded..."
	else
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
fi

# extract ISO
7z x -oextract ${isoname}

# inject ks.cfg
cp ${ks} extract/ks.cfg

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
  append initrd=initrd.img inst.stage2=hd:LABEL=cent7pl quiet inst.ks=cdrom:/dev/cdrom:/ks.cfg netwait=60
EOF

# moving into extract dir
pushd extract

# moved to netinstall - we don't need to createrepo anymore...
# run createrepo, maybe this'll fix the stupid kickstart errors about source not being set up?
# no - this breaks EVERYTHING, no bueno
#rm -rf repodata && createrepo .

# we're trying to find the comps.xml file, which is in some weird naming format
#for file in repodata/*; do
#	zcat $file | head | grep -q '^<comps>'
#	if [ $? -eq 0 ]; then
#		zcat $file > comps.xml && rm -rf repodata
#	fi
#done

# build the repo
#if [ -f comps.xml ]; then
#	createrepo -g comps.xml .
#else
#	echo "Error! Unable to find comps.xml on this ISO - exiting."
#	exit 255
#fi

# build the ISO
mkisofs -o ../${isooutput} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V cent7pl -boot-load-size 4 -boot-info-table -R -J -v -T ../extract

# back a directory
popd

# remove extract directory only if mkisofs is happy
if [ $? -eq 0 ]; then
	rm -rf extract
fi

# done - we only leave the ISO and the shasum files
popd

echo "Done!"
echo "Built ISO file: ${isooutput}"

exit 0
