#!/bin/bash

# variables
tmpfs="/tmp"
basefile="random.file"
ssd="/mnt/backup"

# make sure that tmpfs is mounted
if [ "$(mount | grep ${tmpfs} | awk '{print $5 }')" != "tmpfs" ]; then
	echo "${tmpfs} not mounted, or not mounted as tmpfs - exiting."
	exit 255
fi

# make sure SSD is mounted
mountpoint -q ${ssd}
if [ $? -ne 0 ]; then
	echo "${ssd} is not mounted - exiting."
	exit 255
fi

while true; do
	# need to figure out what the number at the end of the file should be
	if [ ! -f "${ssd}/${basefile}" ]; then
		target="${ssd}/${basefile}"
	else
		tick=0
		count=1
		while [ ${tick} -eq 0 ]; do
			if [ ! -f "${ssd}/${basefile}.${count}" ]; then
				target="${ssd}/${basefile}.${count}"
				tick=1
			fi
			let count++
		done
	fi

	# create random file
	echo "$(date) :: Generating random file..."
	head -c 1G < /dev/urandom > "${tmpfs}/${basefile}"

	# hash the file
	echo "$(date) :: Generating sha256sum hash of generated file..."
	sha="$(sha256sum ${tmpfs}/${basefile} | awk '{ print $1 }')"

	# put the file on the SSD
	echo "$(date) :: Copying file to ${target}..."
	cp ${tmpfs}/${basefile} "${target}"
	if [ $? -ne 0 ]; then
		echo "Error copying file to ${target} -- exiting (this may indicate a hardware failure!)"
		exit 255
	fi

	# check the target sha
	echo "$(date) :: Generating sha256sum hash of ${target}..."
	newsha="$(sha256sum ${target} | awk '{ print $1 }')"

	# compare
	if [ "${sha}" == "${newsha}" ]; then
		echo "$(date) :: Success!"
	else
		echo "$(date) :: Failure! SHA256SUM does not match -- exiting!"
		exit 255
	fi

	# sleep for a random period of time, between 1 and 20 seconds
	echo "$(date) :: Sleeping..."
	sleep $[ ( $RANDOM % 20 ) + 1 ]s
done

# fin
