#!/bin/bash

inputfile=$HOME/serverlist.txt
minionlist=$HOME/minions.grains.20171129

cat $inputfile | while read server; do
	grep -q -i $server $minionlist
	if [ $? -eq 0 ]; then
		echo "$server :: Found" > /dev/null
	else
		echo "$server :: Not Found"
	fi
done

exit 0
