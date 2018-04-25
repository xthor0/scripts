#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Compare file counts and sizes in <dir1> and <dir2>."
	echo "Usage:

`basename $0` -1 <dir1> -2 <dir2>"
	exit 255
}

# get command-line args
while getopts "1:2:l:a:d" OPTION; do
	case $OPTION in
		1) dir1="$OPTARG";;
		2) dir2="$OPTARG";;
		d) debug=1;;
		l) logFile="$OPTARG";;
		a) admin="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$dir1" -o -z "$dir2" -o -z "$admin" ]; then
	usage
fi

if [ -n "$logFile" ]; then
	if [ -f "$logFile" ]; then
		while [ -z "$yesno" ]; do
			echo "$logFile already exists. It will be completely overwritten. OK?"
			read yesno
		done
		if [ "$yesno" == "y" ] || [ "$yesno" == "yes" ]; then
			rm -f "$logFile"
		else
			echo "Exiting..."
			exit 255
		fi
	else
		touch "$logFile"
		if [ $? -ne 0 ]; then
			echo "Could not create log file. Exiting..."
			exit 255
		fi
	fi
	# write header row to logfile
	echo "path,filename,dirFileCount,dirFileCount2,size,sha256,size2,sha256-2,existsOn2,sizematch,sha256match,dirCountMatch,error" > "$logFile"
fi

# make sure the directories exist
if [ -d "$dir1" -a -d "$dir2" ]; then
	if [ -n "$debug" ]; then
		echo "Directories validated, proceeding."
	fi
else
	echo "$dir1 and/or $dir2 is either not a directory, or does not exist."
	exit 255
fi

# functions
function dirCompare() {
dirSize1=`du -s "${1}" | awk '{print $1}'`
dirSize2=`du -s "${2}" | awk '{print $1}'`
if [ $dirSize1 -eq $dirSize2 ]; then
	if [ -n "$debug" ]; then
		echo "$1 : size matches $2"
	fi
	dirSizeMatch=1
else
	echo "$1 : size mismatch, $1 is $dirSize1, $2 is $dirSize2"
	dirSizeMatch=0
fi

fileCount1=`find "${1}" | wc -l`
fileCount2=`find "${2}" | wc -l`
if [ $fileCount1 -eq $fileCount2 ]; then
	if [ -n "$debug" ]; then
		echo "$1 : file count matches, $1: $fileCount1 -- $2: $fileCount2"
	fi
	dirCountMatch=1
else
	echo "$1 : file count mismatch, $1 is $fileCount1, $2 is $fileCount2"
	dirCountMatch=0
fi

# logging
if [ -n "$logFile" ]; then
	echo "$1,,$fileCount1,$fileCount2,$dirSize1,,$dirSize2,,1,$dirSizeMatch,,$dirCountMatch," >> "$logFile"
fi

# don't process the directory if there are no files in it!
if [ $fileCount1 -gt 1 ]; then
	procDir "$1" "$2"
fi
}

function procDir() {
# debugging
if [ -n "$debug" ]; then
	echo "Arguments passed: $1 -- $2"
fi

# process files and directories inside $1
pushd "${1}" >& /dev/null
for entry in *; do
	# we need to know what $entry is -- file or directory
	if [ -f "$entry" ]; then
		echo -n "$entry : "
		let totalFileCount+=1
		# verify that it exists in the same location on $dir2
		if [ -f "${2}/${entry}" ]; then
			fileExistsOn2=1
			# check file sizes
			entrySize1=`du "${1}/${entry}" | awk '{print $1}'`
			entrySize2=`du "${2}/${entry}" | awk '{print $1}'`
			if [ $entrySize1 -eq $entrySize2 ]; then
				if [ -n "$debug" ]; then
					echo -n "File exists in ${2}, and has same size, $entrySize1 -- $entrySize2 : "
				else
					fileSizeMatch=1
					echo -n "size OK : "
				fi
			else
				fileSizeMatch=0
				echo -n "File size mismatch, $1: $entrySize1 -- $2: $entrySize2 : "
			fi

			# check sha256sum
			hash1=`sha256sum "${1}/${entry}" | awk '{print $1}'`
			hash2=`sha256sum "${2}/${entry}" | awk '{print $1}'`
			if [ "$hash1" == "$hash2" ]; then
				if [ -n "$debug" ]; then
					echo "sha256 hashes match, $1: $hash1 -- $2: $hash2"
				else
					sha256match=1
					echo "sha256 OK"
				fi
			else
				sha256match=0
				echo "sha256 hash mismatch, $1: $hash1 -- $2: $hash2"
			fi

		else
			fileExistsOn2=0
			echo "error: file not found in ${2}"
		fi
		
		# logging
		if [ -n "$logFile" ]; then
			echo "$1,$entry,,,$entrySize1,$hash1,$entrySize2,$hash2,$fileExistOn2,$fileSizeMatch,$sha256match,," >> "$logFile"
		fi

	elif [ -d "$entry" ]; then
		let totalDirCount+=1
		if [ -d "${2}/${entry}" ]; then
			if [ -n "$debug" ]; then
				echo "$1/$entry : directory exists on $2."
			fi
			dirCompare "${1}/${entry}" "${2}/${entry}"
		else
			echo "$1/$entry: error, directory does not exist in ${2}"
			# logging
			if [ -n "$logFile" ]; then
				echo "$1,,,,,,,,0,0,,0," >> "$logFile"
			fi
		fi
	else
		echo "$1/$entry: error, not a file or a directory -- error in the script: `pwd`"
		# logging
		if [ -n "$logFile" ]; then
			echo "$1,,,,,,,,,,,,ERROR DETERMINING FILE TYPE" >> "$logFile"
		fi

	fi
done
popd >& /dev/null

}

# file and directory counts (totals)
totalFileCount=0
totalDirCount=0

dirCompare "$dir1" "$dir2"

echo "File compare complete between $dir1 and $dir2.

Totals:

Total files: $totalFileCount
Total directories: $totalDirCount" | mail -s "File Compare on $HOSTNAME" $admin

exit 0
