#!/bin/bash

# source in variables
. /usr/local/bin/servers

# functions
vhostmgr() {
	for server in ${WEB_SERVERS}; do
		echo "$server: "
		ssh ${server} "
			if [ -x `which vhostmgr.sh 2>/dev/null` ]; then
				echo $PASSKEY | sudo -S vhostmgr.sh $action -y $wildcard $client $hostname $docroot
			else
				echo missing vhostmgr.sh on `hostname`, skipping
				exit 255
			fi
		" # DO NOT REMOVE THIS LINE!!
		if [ $? -ne 0 ]; then
			retcode=1
			if [ -z "$failed_server" ]; then
				failed_server=$server
			else
				failed_server="${failed_server} $server"
			fi
		fi
	done

	# check for failures
	if [ -z "$retcode" ]; then
		retcode=0
	fi
	return $retcode
}

clientmgr() {
	for server in ${WEB_SERVERS}; do
		echo "$server: "
		ssh ${server} "echo $PASSKEY | sudo -S clientmgr.sh create $client"
		if [ $? -ne 0 ]; then
			retcode=1
			if [ -z "$failed_server" ]; then
				failed_server=$server
			else
				failed_server="${failed_server} $server"
			fi
		fi
	done
	
	# check for failures
	if [ -z "$retcode" ]; then
		retcode=0
	fi
	return $retcode
}

usage() {
	echo "Usage: `basename $0` -a <action> -c <client> -h <hostname> -d <docroot> -P <sudo password> [ -n ] [ -w ]"
	echo
	echo -e "Valid Actions:\n\n\t\tcreate, destroy, activate, inactivate, docroot, sunset"
	echo
	echo "-n: new client, will automatically run clientmgr.sh on all web servers"
	echo "-w: create domain with wildcards enabled (or subdomains)"
	echo "the -d option is not required if the action requested is sunset, destroy, or inactivate."
	exit 255
}

# parse options
while getopts "a:c:h:d:nP:w" OPTION; do
	case $OPTION in
		a) actionInput="$OPTARG";;
		c) client="$OPTARG";;
		h) hostname="$OPTARG";;
		d) docroot="$OPTARG";;
		n) newClient=1;;
		P) PASSKEY="$OPTARG";;
		w) wildcard="-w";;
		*) usage;;
	esac
done

# verify usage
if [ -z "$actionInput" -o -z "$client" -o -z "$hostname" ]; then
	usage
fi

# verify we were able to source in external variables
if [ -z "${WEB_SERVERS}" ]; then
	echo "This script does not have the proper variables. Contact Infrastructure."
	exit 255
fi

# make sure the action variable is in lower case for further comparison
action="`echo $actionInput | tr [:upper:] [:lower:]`"

# make sure we have a docroot if action is docroot or create
if [ "$action" == "docroot" -o "$action" == "create" ]; then
	if [ -z "$docroot" ]; then
		usage
	fi
fi

# get password if -P was not passed
if [ -z "$PASSKEY" ]; then
	echo "Please type your sudo password: "
	read -s PASSKEY

	# verify passkey is not empty
	if [ -z "$PASSKEY" ]; then
		echo "Must type a passkey."
		exit 255
	fi
fi

# verify -n is only used with create action
if [ "$action" != "create" -a -n "$newClient" ]; then
	usage
fi

# let's run it, baby!
# if -n is passed, we need to create the client first
if [ -n "$newClient" -a "$action" == "create" ]; then
	clientmgr
	
	# check return code
	if [ $retcode -ne 0 ]; then
		echo "clientmgr failed on $failed_server. Correct this problem and run the script again."
		exit 255
	fi
fi

vhostmgr
if [ $retcode -ne 0 ]; then
	echo "vhostmgr failed on server $failed_server."
fi

exit 0
