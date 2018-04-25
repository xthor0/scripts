#!/bin/bash

# script to fix subversion installations -- should be run as root

check=`rpm -qa | grep subversion-tools | wc -l`

yum -y remove neon
if [ $? -eq 0 ]; then
	yum clean all
	if [ $? -eq 0 ]; then
		if [ $check -eq 1 ]; then
			package="subversion-tools"
			yum -y install subversion-tools
			retval=$?
		else
			yum -y install subversion
			package="subversion"
			retval=$?
		fi
		if [ $retval -eq 0 ]; then
			yum -y update
				if [ $? -eq 0 ]; then
					reboot
				else
					echo "Error installing updates."
				fi
		else
			echo "Error installing $package on $HOSTNAME -- please investigate."
		fi
	else
		echo "Error running yum clean all."
	fi
else
	echo "Error removing neon package -- please investigate."
fi
