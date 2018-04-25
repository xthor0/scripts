#!/bin/bash

chpw=/media/sf_bbrown/Dropbox/projects/scripts/change_root_password.sh

if [ ! -x ${chpw} ]; then
	echo "Missing master script: ${chpw} -- exiting."
	exit 255
fi

# display usage
function usage() {
	echo "`basename $0`: Change root password on a bunch of servers."
	echo -e "Usage:\n\n`basename $0` -o oldpassword -n newpassword"
	exit 255
}


servers="
amsterdam.datamark.com
ankara101.datamark.ftp
ankara201.datamark.ftp
beihai.datamark.com
bombay201.datamark.ftp
boston.datamark.com
botswana.datamark-inc.com
brasilia.datamark.com
brussels.datamark.com
caracas.datamark.com
compton.datamark.com
"

# get command-line args
while getopts "o:n:" OPTION; do
	case $OPTION in
		o) oldpass="${OPTARG}";;
		n) newpass="${OPTARG}";;
		*) usage;;
	esac
done

if [ -z "$oldpass" -o -z "$newpass" ]; then
	usage
fi

for server in $servers; do
	$chpw $server "$oldpass" "$newpass"
	#echo "$chpw $oldpass $newpass"
done

exit 0