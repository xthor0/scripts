#!/bin/bash

# variables
. /usr/local/bin/servers

# display usage
function usage() {
	echo "`basename $0`: Clean up <files> from web servers."
	echo "Usage:

`basename $0` <list of directories>"
	exit 255
}

# get command-line args
fileList="$*"

# verify command-line args
if [ -z "$1" ]; then
	usage
fi

# do it
for server in $WEB_SERVERS; do
	echo "#################### $server ###################"
	ssh $server "cd /home/webdocs
	for entry in $fileList; do
		if [ -d \$entry ]; then
			echo Hu3v05C@m313r05 | sudo -S rm -rf \$entry
			if [ \$? -eq 0 ]; then
				echo \"\$entry removed from \$HOSTNAME.\"
			else
				echo \"Error removing \$entry from \$HOSTNAME.\"
			fi
		else
			echo \"\$entry does not exist on \$HOSTNAME.\"
		fi
	done
	" # END SSH SESSION
	if [ $? -eq 0 ]; then
		echo "#################### $server completed ###################"
	else
		echo "#################### $server exited with errors ###################"
	fi
done
exit 0
