#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Fix all vhost files in <path> (remove logging information)."
	echo "Usage:

`basename $0` -p <path to vhost files> (will be processed recursively!!)"
	exit 255
}

# where am I tossing the .bak files?
backupDir="/tmp/vhost-backups"

# get command-line args
while getopts "p:" OPTION; do
	case $OPTION in
		p) VhostPath="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$VhostPath" ]; then
	usage
fi

# verify the vhost path exists
if ! [ -d "$VhostPath" ]; then
	echo "$VhostPath does not exist, or is not a directory."
	usage
fi

# create a backup directory
if [ ! -d "$backupDir" ]; then
	mkdir $backupDir
fi

# do it
echo "Printing . for processed files, ! for errors."
find "$VhostPath" -type f -print | while read file; do
	if [ -f "$file" ]; then
		# back up file
		cp $file $backupDir &>/dev/null
		if [ $? -ne 0 ]; then
			echo "Can't create backup file, quitting!"
			exit 255
		fi

		sed -i.bak '/^ErrorLog.*/d' "$file" &>/dev/null
		if [ $? -eq 0 ]; then
			sed -i.bak '/^CustomLog.*/d' "$file" &>/dev/null
			if [ $? -eq 0 ]; then
				echo -n "."
				rm -f "$file.bak" &>/dev/null
			else
				echo -n "!"
				errorLog="${errorLog}|error removing CustomLog line from $file"
			fi
		else
			echo -n "!"
			errorLog="${errorLog}|error removing ErrorLog line from $file"
		fi
	else
		echo -n "!"
		errorLog="${errorLog}|$file does not exist"
	fi
done

# make sure there are no .bak files left
if [ `find $VhostPath -iname "*.bak" | wc -l 2>/dev/null` -ne 0 ]; then
	echo "Done. Found backup files in $VhostPath, please remove manually."
else
	if [ -n "$errorLog" ]; then
		echo
		echo "Errors found..."
		echo "$errorLog"
	else
		echo "Done."
	fi
fi

exit 0
