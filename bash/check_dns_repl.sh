#!/bin/bash

if [ -n "$1" ]; then
	# get tld
	# see how many periods we have in the string
	dots=${1//[^.]}

	# do some math so we can get the second to last position in the string
	nextlevel=$(expr ${#dots} - 1)

	# finally, break the fqdn into an array and then strip out all but last.tld
	fqdn=(${1//./ })
	tld="${fqdn[${nextlevel}]}.${fqdn[${#dots}]}"

	echo "Finding DNS servers for TLD ${tld}..."

	# get all DNS servers for tld
	dns=$(dig +short -t ns ${tld})
	
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
