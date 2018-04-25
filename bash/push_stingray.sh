#!/bin/sh

# source variables from file
. /usr/local/bin/servers

# functions
function usage() {
        echo "`basename $0`: Push Stingray code to all production app servers."
        echo "Usage:

	`basename $0` -N <stingray release version> -P <releaseman's password> [ -u username ]"
        exit 255
}

# parse command-line args
while getopts "N:P:u:" OPTION; do
	case $OPTION in
		N) release_ver="$OPTARG";;
		P) password="$OPTARG";;
		u) username="$OPTARG";;
		*) usage;;
	esac
done

# verify all variables are set correctly
if [ -z "$release_ver" ]; then
	usage
fi

if [ -z "$username" ]; then
	username="releaseman"
fi

if [ -z "$password" ]; then
	echo "Please enter the password for $username: "
	while [ -z "$password" ]; do
		read -s password
	done
fi

# verify we got the right variables from source file
if [ -z "${APP_SERVERS}" ]; then
	echo "Apparently, I didn't get the right variables. Contact Infrastructure."
	exit 255
fi

for server in ${APP_SERVERS}; do
	echo "$server: "
	ssh ${username}@${server} "
		echo $password | sudo -S stingray_live_setup.sh $release_ver
	" # DO NOT REMOVE THIS LINE!!
	if [ $? -ne 0 ]; then
		echo "Error pushing Stingray version $release_ver to $server!"
		echo "Go get help. I'll wait here. (push enter to continue)"
		read
	fi
done

exit 255
