#!/bin/bash

counter=0
while true; do
	let counter+=1; echo $(date) :: $counter
	sleep 1
done

exit 0
