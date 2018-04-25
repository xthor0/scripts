#!/bin/bash

if [ -n "$1" ]; then
	# get tld
	tld=${1#*.}
	#echo $tld

	# get all DNS servers for tld
	dns=$(dig +short -t ns ${tld})
	#echo $dns

	if [ ${#dns} -eq 0 ]; then
		echo "Unable to find DNS servers for ${tld}."
		exit 255
	fi

	# loop through DNS servers and check this record against each server
	for server in ${dns}; do
		result=$(dig +short ${1} @${server})
		echo "${server} :: ${result}"
	done
else
	echo "Must specify a domain name."
fi

exit 0
