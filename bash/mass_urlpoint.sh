#!/bin/sh

inputFile=$1

if [ -z "$inputFile" -o ! -f "$inputFile" ]; then
	echo "Either the input file you specified does not exist, or you didn't pass an argument."
	exit 255
fi

cat "$inputFile" | while read line; do
	url=`echo $line | cut -d ' ' -f 1`
	docroot=`echo $line | cut -d ' ' -f 2`
	client=`echo $line | cut -d ' ' -f 3`

	# verify url and docroot are not empty
	if [ -z "$url" -o -z "$docroot" -o -z "$client" ]; then
		echo "Problem: url, docroot, or client variables are null. Verify input file is formatted correctly."
		exit 255
	fi

	# make the vhost change
	echo "$HOME/projects/scripts/global_vhostmgr.sh -a docroot -c $client -h $url -d $docroot -P Hu3v05C@m313r05"
done

exit 0
