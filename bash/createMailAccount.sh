#!/bin/sh

password_list="/root/email_accounts.txt"
pwgen_bin="`which pwgen`"
adduser_bin="`which adduser`"
username="$1"

# must be run as root
if [ $UID -ne 0 ]; then
	echo "You must be root to run this script."
	exit 255
fi

# make sure we can find the pwgen bin
if [ ! -x $pwgen_bin ]; then
	echo "pwgen is either not installed, or not in the path."
	echo "Please correct the problem and run this script again."
	exit 255
fi

# make sure we can find the adduser bin
if [ ! -x $adduser_bin ]; then
	echo "adduser is either not installed, or not in the path."
	echo "Please correct the problem and run this script again."
	exit 255
fi

function usage() {
	echo "Usage: $0 [username]"
	exit 255
}

# check args
if [ -z "$username" ]; then
	usage
fi

### let's do it
password="`$pwgen_bin -c -n 8 1`"
$adduser_bin -s /sbin/nologin $username
if [ $? -eq 0 ]; then
	echo $password | passwd --stdin $username
	if [ $? -eq 0 ]; then
		echo "Created $username with password $password."
		echo "$username:$password" >> $password_list
	else
		echo "Error setting password $password for $username. Please set it manually and add it to $password_list."
		exit 255
	fi
else
	echo "There was an error creating $username."
	exit 255
fi

exit 0
