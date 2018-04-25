#!/bin/bash

TARGET=${1}
if [ -z "$TARGET" ]; then
	echo "Must specify an IP address or a hostname running Apache"
	echo "with the server-status module loaded..."
	exit 255
fi

# header
printf "%-20s %s\n" Date "Apache Connections"
printf "%0.s=" {1..50}
echo

while true; do
	curl -s --connect-timeout 2 http://${TARGET}/server-status | grep 'requests currently being processed' > /tmp/apache.out
	if [ $? -eq 0 ]; then
		result=$(cat /tmp/apache.out | awk '{ print $1 }' | cut -d \> -f 2)
		printf "%-20s %d\n" "$(date +%X)" $result
	else
		echo "Error connecting to $TARGET -- will retry..."
	fi

	sleep 2
done

exit 0
