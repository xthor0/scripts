#!/bin/bash

# variables
admin="ben.brown@datamark.com"

# display usage
function usage() {
	echo "`basename $0`: Check to make sure a path is mounted."
	echo "Usage:

`basename $0` -M /path/to/check"
	exit 255
}

function emailAlert() {
		echo "$1" | mail -s "Mount point problem on `hostname`" $admin
}

# get command-line args
while getopts "M:" OPTION; do
	case $OPTION in
		M) mountPoint="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$mountPoint" ]; then
	usage
fi

# do it
if [ -d "$mountPoint" ]; then
	checkMnt=$(mount | grep $mountPoint | awk '{ print $3 }')
	if [ "$checkMnt" != "$mountPoint" ]; then
		emailAlert "$mountPoint is not mounted, needs to be fixed ASAP."
		exit 255
	fi
else
	emailAlert "$mountPoint does not exist as a directory. This problem needs to be fixed ASAP."
fi
exit 0
