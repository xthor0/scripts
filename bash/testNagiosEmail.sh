#!/bin/bash

# variables
servers="stockholm washingtondc brussels"

# display usage
function usage() {
	echo "`basename $0`: Send test Nagios alerts to specified address."
	echo "Usage:

`basename $0` -R user.email@domain.com [ -P Sud0P@ssW0rd! ]"
	exit 255
}

# get command-line args
while getopts "R:P:" OPTION; do
	case $OPTION in
		R) recipient="$OPTARG";;
		P) sudopw="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$recipient" ]; then
	usage
fi

# get password here if not specified on command-line
while [ -z "$sudopw" ]; do
	echo "Please enter your sudo password: "
	read -s sudopw
done

# do it
for server in $servers; do
	ssh $server.datamark.com "
		echo $sudopw | sudo -S whoami > /dev/null 2>&1
		if [ \$? -eq 0 ]; then
			echo \"From: nagios@\$HOSTNAME
To: $recipient
Importance: high
Subject: ** PROBLEM alert 1 - Nagios Test Message **

Nagios Notification Type: TEST

Service: Nagios Alert Test
Host: \$HOSTNAME
State: TEST ALERT

Info:
This is a test Nagios alert

Date/Time: `date`
\" | sudo -u nagios /usr/sbin/sendmail -t
			if [ \$? -eq 0 ]; then
				echo \"\${HOSTNAME}: Message sent\"
			else
				echo \"\${HOSTNAME}: Error sending message\"
			fi
		else
			echo \"\${HOSTNAME}: Check sudo password, there was an error authenticating.\"
		fi
	" # END SSH SESSION
done

exit 0