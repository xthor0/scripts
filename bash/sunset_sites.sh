#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Mass sunset sites, takes an input file in CSV format of domain,client."
	echo "Usage:

`basename $0` -f inputfile [ -P password ]"
	exit 255
}

# get command-line args
while getopts "f:P:" OPTION; do
	case $OPTION in
		f) inputfile="$OPTARG";;
		P) password="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$inputfile" ]; then
	usage
fi

# if no password, prompt for it
if [ -z "$password" ]; then
	echo "Please enter the password for $username: "
	while [ -z "$password" ]; do
		read -s password
	done
fi

# do it
linenum=0
for line in `cat "$inputfile"`; do

	# count line numbers
	let linenum+=1

	# parse line
	domain="`echo $line | cut -d \, -f 1`"
	client="`echo $line | cut -d \, -f 2`"

	# verify no nulls
	if [ -z "$domain" -o -z "$client" ]; then
		echo "Skipping line $linenum... (nulls)"
		continue
	fi

	# if the client = "none", this domain doesn't exist anymore
	if [ "$client" == "none" ]; then
		$HOME/projects/scripts/global_vhostmgr.sh -a create -c datamark -h $domain -d /home/webdocs/rmtesting/public_html/sites/sunset -P $password
	else
		$HOME/projects/scripts/global_vhostmgr.sh -a sunset -c $client -h $domain -P $password
	fi

done

exit 0
