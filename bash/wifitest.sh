#!/bin/bash

while true; do
	echo "$(date) :: Testing network..."
	ping -q -c 10 -w 10 10.200.99.1 >& /dev/null
	if [ $? -eq 0 ]; then
		echo "$(date) :: Network test passed"
	else
		echo "$(date) :: Network test FAILED"
	fi

	sleep 5
done

exit 0
