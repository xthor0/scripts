#!/bin/sh

if [ -z "$*" ]; then
	echo "You must pass a command to this script."
	exit 255
fi

# source in variables
. /usr/local/bin/servers

for server in $WEB_SERVERS; do
	echo "$server: "
	ssh $server "$*"
done

exit 0
