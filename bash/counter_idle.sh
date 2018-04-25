#!/bin/bash

counter=0
while true; do
	let counter+=1
	idletime=$(echo "scale=2;$(xprintidle)/1000" | bc)
	echo $(date) :: Counter: $counter :: Seconds idle: ${idletime}
	sleep 1
done

exit 0
