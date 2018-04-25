#!/bin/bash

# variables
var="var1"

# display usage
function usage() {
	echo "`basename $0`: Blah."
	echo "Usage:

`basename $0` -r <recipient> -m \"message\" [ -h ] (NOTE: MESSAGE MUST BE IN QUOTES!"
	exit 255
}

# get command-line args
while getopts "r:m:h" OPTION; do
	case $OPTION in
		r) recipient="$OPTARG";;
		m) message="$OPTARG";;
		h) highPrio=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$recipient" -o -z "$message" ]; then
	usage
fi

# we need sendmail
if ! [ -x /usr/sbin/sendmail ]; then
	echo "Missing sendmail. I die."
	exit 255
fi

# do it


email="From: reminder@nobody.com
To: $recipient"
if [ -n "$highPrio" ]; then
	email="${email}
Importance: high"
fi
email="${email}
Subject: Reminder!
$message
"

echo "$email" | /usr/sbin/sendmail -t
retval=0
if [ $retval -eq 0 ]; then
	echo "Message sent successfully!"
else
	echo "Error sending message."
fi
exit $retval
