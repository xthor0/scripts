#!/bin/bash

# variables
source="http://releases.ubuntu.com/18.04/ubuntu-18.04.2-live-server-amd64.iso"
shatxt="http://releases.ubuntu.com/18.04/SHA256SUMS"
build="$HOME/tmp/ubuntu-iso"
shaname=$(basename ${shatxt})
isoname=$(basename ${source})

# we need command-line options
while getopts "p:f:" opt; do
	case $opt in
		p)
			preseed=$OPTARG
			;;
		f)
			outfile=$OPTARG
			;;
	esac
done

# validate arguments...
if [ -z "${preseed}" ]; then
	echo "You must specify the location of a Ubuntu preseed file with the -p option!"
	exit 255
fi

if [ -z "$outfile" ]; then
	echo "You must specify the base output file name with -f"
	echo "example: $(basename $0) -f vbox -- output file: ubuntu-vbox-$(date +%Y%m%d).iso"
	exit 255
fi

# make sure the preseed file exists
if [ -f "${preseed}" ]; then
    echo "Using preseed file: ${preseed}"
else
    echo "Error: file not found: ${preseed}"
    exit 255
fi

# name of output file
output="ubuntu-${outfile}-$(date +%Y%m%d).iso"

# create the build directory
if [ ! -d "${build}" ]; then
    mkdir -p "${build}"
fi

pushd "${build}"

# download the SHA512SUMS file
wget -q ${shatxt}
if [ $? -eq 0 ]; then
    echo "$(grep ${isoname} SHA256SUMS | awk '{ print $1 }')  ${isoname}" > sha.txt
else
    echo "Error: Unable to download ${shatxt}. Exiting."
    exit 255
fi

# download the netinst ISO
if [ -f ${isoname} ]; then
    echo "${isoname} has already been downloaded."
else
    echo "Downloading ${source}..."
    wget --no-clobber --show-progress -q ${source}
fi

# check hash
if [ $? -eq 0 ]; then
    sha256sum -c sha.txt
    if [ $? -ne 0 ]; then
        echo "Failed to verify SHA512SUM of ${isoname} -- exiting."
        exit 255
    fi
else
    echo "Unable to download ISO."
    exit 255
fi

# extract the ISO
7z -ox x ${isoname}
if [ $? -ne 0 ]; then
    echo "Failed to extract ${isoname} -- exiting."
    exit 255
fi

# replace isolinux.cfg
cat << EOF > x/isolinux/isolinux.cfg 
default linux
timeout 200

label linux
	menu label ^Install
   	kernel /casper/vmlinuz
	append boot=casper initrd=/casper/initrd quiet  --- locale=en_US.UTF-8 keymap=us file=/cdrom/preseed.cfg 
EOF

# inject preseed.cfg
cp ${preseed} x/preseed.cfg
if [ $? -ne 0 ]; then
    echo "Error copying ${preseed} -- exiting."
    exit 255
fi

# generate ISO
echo "Generating ISO: ${build}/${output}"
genisoimage -quiet -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${build}/${output} x
if [ $? -eq 0 ]; then
    # cleanup
    rm -rf x ${shaname} sha.txt
else
    echo "Error generating ISO."
fi

popd
exit 0