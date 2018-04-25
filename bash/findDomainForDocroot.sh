#!/bin/bash

# variables
sitesAvailable="/etc/httpd/sites-available"

# display usage
function usage() {
	echo "`basename $0`: Find URL for docroot."
	echo "Usage:

`basename $0` -F inputfile.txt
inputfile.txt should be a tab-separated text file"
	exit 255
}

# get command-line args
while getopts "F:" OPTION; do
	case $OPTION in
		F) inputFile="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$inputFile" ]; then
	usage
fi

# do it
echo "Processing $inputFile..."
if ! [ -d $sitesAvailable ]; then
	echo "This is not a production microsite server."
	exit 255
fi

# parse the file
cat $inputFile | while read line; do
	docroot=`echo $line | awk '{ print $1 }'`
	clientCode=`echo $line | awk '{ print $2 }'`
	domain="`grep -ri -A1 $docroot $sitesAvailable/* | grep ServerName | awk '{ print $2 }'`"
	if [ -n "$domain" ]; then
		echo "Found: $domain"
	else
		echo "No result."
	fi
done

exit 0
