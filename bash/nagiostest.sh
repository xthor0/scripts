#!/bin/bash

# usage
function usage() {
	echo "`basename $0`: Generate an alert depending on argument passed on command-line."
	echo
	echo "ex: `basename $0` [ -c | -w | -o ]"
	echo "where -c = critical, -o = ok, and -w = warning"
	exit 255
}

# cli args
while getopts "ocw" OPTION; do
	case $OPTION in
		o) STATUS="OK"; retval=0;;
		c) STATUS="CRITICAL"; retval=2;;
		w) STATUS="WARNING"; retval=1;;
		*) usage;;
	esac
done

if [ -z "$STATUS" ]; then
	usage
fi

echo -n "${STATUS}: This is a Nagios alert test."
exit $retval
