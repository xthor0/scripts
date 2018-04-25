#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Convert string to lowercase."
	echo "Usage:

`basename $0` <string>

Anything passed to this script gets converted, spaces and all."
	exit 255
}

# verify command-line args
if [ -z "$*" ]; then
	usage
fi

# do it
echo "$*" | tr [:upper:] [:lower:]
exit 0
