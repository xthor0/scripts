#!/bin/bash 

FILE=apollo01.apache.log
for ip in $(cat $FILE | grep '20\/Jun\/2014' | awk '{ print $2 }' | sort | uniq); do
	COUNT=$(grep $ip.*20\/Jun\/2014 $FILE | wc -l)
	if [[ "$COUNT" -gt "10" ]]; then
		echo "$COUNT:   $ip"; 
	fi
done  
