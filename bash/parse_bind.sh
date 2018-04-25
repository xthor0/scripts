#!/bin/bash

# variables
var="var1"

# display usage
function usage() {
	echo "`basename $0`: Parse hosts from a bind zone file."
	echo "Usage:

`basename $0` -d <path to bind zone files>"
	exit 255
}

# get command-line args
while getopts "d:" OPTION; do
	case $OPTION in
		d) dir="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$dir" ]; then
	usage
fi

# do it
if [ -d "${dir}" ]; then
	# parse each record and find a valid DNS
	find ${dir} -iname "*.dns" | while read file; do
		domain=$(basename ${file} .dns | tr [:upper:] [:lower:])
		echo -n "${domain},"
		cat ${file} | expand | grep ' A ' | grep -v '^ns-auth.datamark.com.' | grep -v '^@' | while read record; do
			base=$(echo $record | awk '{ print $1 }')
			ip=$(echo $record | awk '{ print $3 }')
			#echo "address=/${base}.${domain}/${ip}"
			echo "${base},${ip}"
		done
		unset base ip domain
	done
fi

exit 0
