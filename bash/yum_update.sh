#!/bin/bash

myid=$(id -u)

if [ ${myid} -ne 0 ]; then
	echo "Sudo, stupid, sudo."
	exit 255
fi

/usr/bin/yum clean all
if [ $? -ne 0 ]; then
	echo "Yum clean failed."
	exit 255
fi

/usr/bin/yum check-update
if [ $? -eq 100 ]; then
	kernel=$(rpm -qa | grep kernel | sha1sum)
	/usr/bin/yum -y update
	if [ $? -eq 0 ]; then
		version=$(cat /etc/redhat-release | awk '{ print $$3 }')
		newkernel=$(rpm -qa | grep kernel | sha1sum)
		if [ "$newkernel" != "$kernel" ]; then
			echo "Version: ${version}"
			reboot
		else
			echo "Updates are done!"
		fi
	else
		echo "Error during updates."
	fi
else
	echo "No updates."
fi

exit 0
