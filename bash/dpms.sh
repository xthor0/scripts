#!/bin/bash

# dpms is being completely ignored - happened on two different distros now

# loop forever
while true; do
	# get monitor current status
	echo ":: $(date) :: Next run!"
	state="$(xset q | grep 'Monitor is' | awk '{ print $3 }')"
	echo "Monitor is currently $state"

	if [ "$state" == "On" ]; then
		echo "Monitor is $state -- supposed to be off!"
		xset dpms force off
	else
		echo "Monitor is already $state (expected: Off)"
	fi

	# sleep for at least one minute
	echo "Sleeping 1 minute.."
	sleep 1m
done

exit 0
