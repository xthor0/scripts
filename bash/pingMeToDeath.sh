#!/bin/bash

# variables
fping="/usr/sbin/fping"

# make sure we have fping
if ! [ -x $fping ]; then
	echo "You need to install fping."
	exit 255
fi

# display usage
function usage() {
	echo "`basename $0`: Ping a bunch of IP addresses, at random intervals, until we"
        echo "get a failure."
	echo "Usage:

`basename $0` -L ip.addr.1[:ip.addr.2:...]"
	exit 255
}

function trafficToIp() {
	ipcheck=$(echo $1 | grep -E '(([0-1]?[0-9]{1,2}\.)|(2[0-4][0-9]\.)|(25[0-5]\.)){3}(([0-1]?[0-9]{1,2})|(2[0-4][0-9])|(25[0-5]))')
	if [ -z "$ipcheck" ]; then
		echo "$ip is not a valid IP address."
		return 255
	fi

	# randomize -- send between 5 and 25 ICMP packets
	packetCount=0
	while [ $packetCount -lt 4 -o $packetCount -gt 26 ]; do
		packetCount=$RANDOM
	done

	if [ -n "$debug" ]; then
		echo "DEBUG: Sending $packetCount ICMP packets to $ip"
	fi

	# let's send some traffic!
	pingOutput=$($fping -q -c $packetCount $ip 2>&1)
	pingResult=$?

	if [ -n "$debug" ]; then
		if [ $pingResult -ne 0 ]; then
			echo "DEBUG: Errors pinging $ip"
		fi
		echo "DEBUG: $pingOutput"
	fi

	return $pingResult
}

function sendAlert() {
	echo $1 | mail -s "Ping Problems on $HOSTNAME" $2
}

# get command-line args
while getopts "L:A:d" OPTION; do
	case $OPTION in
		L) iplist="$OPTARG";;
		A) admin="$OPTARG";;
		d) debug=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$iplist" -o -z "$admin" ]; then
	usage
fi

# do it
loop=0
while true; do
	let loop+=1
	echo "$iplist" | tr \: \\n | while read ip; do
		trafficToIp $ip
		retVal=$?

		if [ $retVal -eq 255 ]; then
			breakOut=1
			break
		elif [ $retVal -ne 0 ]; then
			sendAlert "Error communicating with a host: $pingOutput loops: $loop" $admin
		fi
	done

	# are we supposed to be done?
	if [ -n "$breakOut" ]; then
		break
	fi

	# and to finish out -- we sleep for somewhere between 5 minutes and 30 minutes.
	sleepTime=0
	while [ $sleepTime -lt 599 -o $sleepTime -gt 1800 ]; do
		sleepTime=$RANDOM
	done

	if [ -n "$debug" ]; then
		echo "DEBUG: Sleeping $sleepTime seconds..."
	fi
	sleep $sleepTime
done

exit 0
