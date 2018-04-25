#!/bin/bash

# variables
inputFile="$HOME/WinHome/Desktop/all tzo domains.txt"

# args
outputFile="$1"
testCount="$2"

# check args
if [ -z "$outputFile" ]; then
	echo "No output file specified."
	exit 255
fi

# clear output file
if [ -f "$outputFile" ]; then
	echo "This file will be overwritten. Type \"no\" below if this is a problem."
	read yesno
	if [ -n "$yesno" ]; then
		echo "Exiting."
		exit 255
	else
		# write header row
		echo "domain,ns1,ns2,ns3,ns4,ns5,ns6,ns7,ns8" > $outputFile
	fi
fi

count=0
cat "$inputFile" | while read domain; do
	if [ -n "$domain" ]; then
		echo -n "Processing $domain... "
		echo -n "$domain," >> $outputFile
		nsResult="`host -t ns $domain. | grep 'name server' | awk '{ print $4 }' | sort | sed 's/\.$/,/g' | tr -d \\\\n`"
		if [ -z "$nsResult" ]; then
			echo "null" >> $outputFile
		else
			echo "$nsResult" >> $outputFile
		fi

		let count+=1
		echo "Done."
		if [ -n "$testCount" ]; then
			if [ $count -ge $testCount ]; then
				echo "Max count of $testCount specified -- exiting."
				exit 255
			fi
		fi
	fi
done

exit 0
