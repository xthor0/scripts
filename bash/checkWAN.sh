#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Verify specified ethernet interface has not lost it's DHCP lease."
	echo "Usage:

`basename $0` -i ethX"
	exit 255
}

# get command-line args
while getopts "i:d" OPTION; do
	case $OPTION in
		i) int="$OPTARG";;
		d) debug=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$int" ]; then
	usage
fi

# do it
ipaddr="`/sbin/ifconfig $int | grep 'inet addr' | awk '{ print $2 }' | cut -d \: -f 2`"
if [ -n "$debug" ]; then
	echo "DEBUG: Interface $int has IP $ipaddr"
fi

if [ -z "$ipaddr" ]; then
	if [ -n "$debug" ]; then
		echo "DEBUG: Interface $int has null IP, restarting networking"
	fi

	/sbin/service network restart > /dev/null 2>&1
	ipaddr="`/sbin/ifconfig $int | grep 'inet addr' | awk '{ print $2 }' | cut -d \: -f 2`"
	if [ -n "$debug" ]; then
		echo "DEBUG: After network restart, interface $int has IP $ipaddr."
	fi
	
	if [ -n "$ipaddr" ]; then
		echo "Lost IP address on $int, forced network restart." | mail -s "Network Restart on $hostname" xthor@xthorsworld.com
	fi
fi

exit 0
