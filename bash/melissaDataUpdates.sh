#!/bin/bash

# are we root?
if [ ${UID} -ne 0 ]; then
	echo "You need to run $0 as root or with sudo."
	exit 255
fi

# Give some feedback so the user knows something is happening...
echo "Starting Melissa Data update process... please wait..."

# mountpoint for melissa data files
mdPath=/mnt/greenbrier

# make sure path is mounted via NFS
mountpoint -q ${mdPath}
retval=$?

if [ ${retval} -eq 0 ]; then
	echo "${mdPath} is already NFS mounted -- proceeding with update process..."
else
	if [ ! -d ${mdPath} ]; then
		mkdir ${mdPath}
		if [ $? -ne 0 ]; then
			echo "error: could not create ${mdPath}"
			exit 255
		fi
	fi

	# mount the NFS path
	echo "${mdPath} is not mounted -- mounting NFS path on Greenbrier..."
	mount greenbrier.datamark.com:/storage/melissadata ${mdPath}
	mountpoint -q ${mdPath}
	if [ $? -ne 0 ]; then
		echo "Error mounting NFS path on greenbrier. Check above errors and see if ${mdPath} is mounted."
		exit 255
	fi
fi

# change directory
pushd ${mdPath} >& /dev/null

# output message
echo "Checking for required Melissa Data files..."

# check to make sure all required files are present
for file in Addr.dbf mdAddr.dat mdAddr.str mdGeoCanada.db mdGeo.idx mdGeoPoint.dat mdPhone.idx Congress.dbf mdAddr.lic mdCbsa.dat mdGeo.cty mdGeo.lic mdGeoPoint.idx ZIPNPA.TXT ews.txt mdAddr.nat mdCbsa.idx mdGeo.dat mdGeo.plc mdPhone.dat; do
	if [ ! -f ${file} ]; then
		echo "Missing file: ${file}"
		fileCheck=1
	fi
done

# error out if we find a missing file
if [ -n "${fileCheck}" ]; then
	echo "Error: Missing one or more files in Melissa Data sources. Please copy them to /storage/melissadata on Greenbrier to correct the problem."
	exit 255
fi

# output status
echo "Beginning file copy from ${mdPath} to /var/lib/melissadata..."

# copy the files to the correct location and correct permissions and SELinux contexts
cp * /var/lib/melissadata && chmod 644 /var/lib/melissadata/* && chcon system_u:object_r:httpd_sys_content_t /var/lib/melissadata/* && chown root:root /var/lib/melissadata/*
if [ $? -ne 0 ]; then
	echo "Error installing the latest Melissa Data updates."
fi

popd >& /dev/null

# unmount NFS path
umount ${mdPath}

echo "Melissa Data updates have been successfully installed."

exit 0
