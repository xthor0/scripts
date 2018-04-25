#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Check IP address of specified network interface and email an address if it's changed since the last run."
	echo "Usage:

`basename $0` -i <ethernet interface>"
	exit 255
}

# get command-line args
while getopts "i:" OPTION; do
	case $OPTION in
		i) nic="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$nic" ]; then
	usage
fi

# variables
ipinfo_file="$HOME/.${nic}.ipinfo"
log="$HOME/check_ip.log"

# functions for use elsewhere in script
function logCheck {
	logMessage="$1"
	echo "[`basename $0`: `date +%x\ %X`] $logMessage" >> $log
}

function emailAdmin {
	messageContent="$1"
	logCheck "$messageContent"
	#echo "$messageContent" | mail -s "IP Address Change on $HOSTNAME" $admin
	$HOME/nma.sh "IP Address Change" "$HOSTNAME" "$messageContent" 0
}

# do it
## does $nic exist?
if [ -d /proc/sys/net/ipv4/conf/${nic} ]; then
	# get IP of nic
	current_ip="`/sbin/ifconfig ${nic} | grep 'inet addr' | awk '{ print $2 }' | cut -d \: -f 2`"
	# do we have a previous IP file?
	if [ -f "$ipinfo_file" ]; then
		# does it have the right info in it?
		. $ipinfo_file
		if [ -n "$previous_ip" ]; then
			# check differences
			if [ "$current_ip" != "$previous_ip" ]; then
				emailAdmin "The IP address of $HOSTNAME has changed from $previous_ip to $current_ip." $email
				writeInfo=1
			else
				logCheck "No change in IP address."
			fi
		else
			# we'll need to replace this file
			writeInfo=1
		fi
	else
		# write ip info to file
		writeInfo=1
	fi
	
	# do we need to write a new file?
	if [ -n "$writeInfo" ]; then
		echo "previous_ip=$current_ip" > $ipinfo_file
		logCheck "Wrote IP address $current_ip to $ipinfo_file."
	fi
else
	echo "$nic is not a valid network interface, or does not have an IP address."
	exit 255
fi

exit 0
