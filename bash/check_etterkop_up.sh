#!/bin/bash

lastcheck=0
while true; do
	ping -c1 -w1 etterkop.xthorsworld.com >& /dev/null
	retval=$?

	if [ $retval -ne 0 ]; then
		if [ $retval -ne $lastcheck ]; then
			echo "$(date) :: status change, Etterkop is down, sending Pushover message..."
			~/Dropbox/projects/scripts/pushover_msg.sh Etterkop is DOWN
		else
			echo "$(date) :: Etterkop is still down, no need to send another message..."
		fi
	else
		echo "$(date) :: Etterkop is up"
	fi
	
	# sleep for one minute
	sleep 60
done

# fin
