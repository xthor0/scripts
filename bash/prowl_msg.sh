#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Send me a quick Prowl message."
	echo "Usage:

`basename $0` -m \"message\" [ -h ] (NOTE: MESSAGE MUST BE IN QUOTES!)"
	exit 255
}

# get command-line args
while getopts "r:m:h" OPTION; do
	case $OPTION in
		m) message="$OPTARG";;
		h) highPrio=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$message" ]; then
	usage
fi

# we need Prowl
prowl=$HOME/Dropbox/projects/scripts/prowl.pl
if ! [ -x $prowl ]; then
	echo "Missing prowl -- cannot continue."
	exit 255
fi

# do it
$prowl -apikey=fb18cb558102482e883ac76ba05a3c1b00212e96 -application="Quick message" -event="Quick message" -notification="$message" -priority=-2
retval=$?
if [ $retval -eq 0 ]; then
	echo "Message sent successfully!"
else
	echo "Error sending message."
fi
exit $retval
