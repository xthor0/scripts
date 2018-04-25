#!/bin/bash

# get default gateway
# if default gateway is null, sleep for five seconds and try again
count=0
while [ -z "$defgw" -a $count -le 10 ]; do
	sleep 5
	let count++
	defgw="`route -n | grep UG | awk '{ print $2 }'`"
done

# once a default gateway is active, make sure we can ping out
retval=1
while [ $retval -ne 0 ]; do
	ping -c1 -w1 -q 8.8.8.8 >& /dev/null
	retval=$?
	sleep 5
done

# start pidgin in the background
pidgin &

exit 0
