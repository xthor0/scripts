#!/bin/sh

# display usage
function usage() {
	echo "`basename $0`: Push script to QA."
	echo "Usage:

`basename $0` -s <script to push> -d <destination server> -P <sudo password>"
	exit 255
}

# get command-line args
while getopts "s:d:P:" OPTION; do
	case $OPTION in
		s) source="$OPTARG";;
		d) dest="$OPTARG";;
		P) password="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$source" -o -z "$dest" ]; then
	usage
fi

# get password
if [ -z "$password" ]; then
	echo "Please enter your password: "
	while [ -z "$password" ]; do
		read -s password
	done
fi

# does the source file exist?
if [ ! -f "$source" ]; then
	echo "Missing $source."
	exit 255
fi

# get basename of $source
basefile=`basename $source`

# have the files changed?
local_sha=`openssl sha1 $source | awk '{ print $1 }'`
remote_sha=`ssh ${dest} "sha1sum /usr/local/bin/$basefile | cut -d \  -f 1"`

if [ "$local_sha" == "$remote_sha" ]; then
	echo "No changes in $source on $dest."
	exit 255
fi

# do it
scp "$source" ${dest}:
if [ $? -ne 0 ]; then
	echo "Error copying $source to $dest."
	exit 255
fi


# move the file to /usr/local/bin, and change permissions/context
ssh ${dest} "echo $password | sudo -S mv $basefile /usr/local/bin && sudo chown root:root /usr/local/bin/$basefile && sudo chcon system_u:object_r:bin_t /usr/local/bin/$basefile"
if [ $? -ne 0 ]; then
	echo "Error installing $basefile on $dest."
	exit 255
fi

exit 0
