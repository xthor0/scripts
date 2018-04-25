#!/bin/bash

temp="/tmp/index.html.tmp"
comparison_temp="/tmp/index.html.$verified_server.tmp"

# display usage
function usage() {
	echo "`basename $0`: Check to see if a domain's creative has been updated"
	echo "across all servers in the web pool."
	echo "Usage:

`basename $0` -V <hostname of verified server> -u <domain name>"
	exit 255
}

# get command-line args
while getopts "V:u:" OPTION; do
	case $OPTION in
		V) verified_server="$OPTARG";;
		u) url="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$verified_server" -o -z "$url" ]; then
	usage
fi

# source in variables
. /usr/local/bin/servers
if [ -z "$WEB_SERVERS" ]; then
	echo "Cannot source correct variables, exiting."
	exit 255
fi

# get verified URL
echo "GET / HTTP/1.0
host: $url
" | nc $verified_server 80 | grep -v '^Date: ' > $comparison_temp
verified_hash="`openssl sha1 $comparison_temp | awk '{ print $2 }'`"

for server in $WEB_SERVERS; do
	if [ "$server" == "$verified_server" ]; then
		continue
	fi

	echo "GET / HTTP/1.0
host: $url
" | nc $server 80 | grep -v '^Date: ' > $temp
	compared_hash="`openssl sha1 $comparison_temp | awk '{ print $2 }'`"
	if [ "$compared_hash" == "$verified_hash" ]; then
		echo "$server - $url: OK"
	else
		echo "$server - $url: CRITICAL -- mismatch"
	fi
done

rm -f $temp $comparison_temp

exit 0
