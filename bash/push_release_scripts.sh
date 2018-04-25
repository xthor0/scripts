#!/bin/sh

# variables
# source in server variables
. servers

targetDir="/usr/local/bin"
sourcePushScripts="global_vhostmgr.sh push_stingray.sh servers"
sourceCheckoutScripts="stingray_live_setup.sh kill_lead_processor.sh kill_trigger_deliverer.sh"
pushScriptsServer="mesquite.datamark.com"
ALL_APP_SERVERS="${APP_SERVERS} stseville.datamark.com"

# display usage
function usage() {
	echo "`basename $0`: Pushes delivery scripts to $pushScriptsServer and all Stingray app servers."
	echo "Your user account needs Sudo rights on the target machines, as well as shared SSH keys."
	echo "Usage:

	`basename $0` -P <password on remote machine>"
	exit 255
}

# verify command-line options
while getopts "P:" OPTION; do
	case $OPTION in
		P) password="$OPTARG";;
		*) usage;;
	esac
done

# verify password was passed on command-line, otherwise ask for it
if [ -z "$password" ]; then
	echo "Please enter your password: "
	while [ -z "$password" ]; do
		read -s password
	done
fi

# do it to it

###############
## Functions ##

function verifyAndPush() {
	# grab $1 and use it as $file
	file="$1"
	server="$2"
	copy_file=0
	# verify it exists in cwd
	if [ -f "$file" ]; then
		# get local hash and remote hash, and compare
		local_sha1=`openssl sha1 $file | awk '{ print $2 }'`
		
		# determine if file exists on remote machine
		remoteFileExist=`ssh $server "if test -f $targetDir/$file; then echo 1; else echo 0; fi" 2>/dev/null`

		# verify we got a result
		if [ -z "$remoteFileExist" ]; then
			# this usually indicates connectivity problems
			echo "Unable to determine status of remote files. Please verify you have shared SSH keys and the rights to access the files in question."
			exit 255
		fi

		# if the file exists on the remote server, compare them, and copy if necessary.
		# If the file does not exist on the remote server, copy it.
		if [ $remoteFileExist -eq 1 ]; then
			remote_sha1=`ssh $server "sha1sum $targetDir/$file | cut -d ' ' -f 1"`
			if [ "$local_sha1" == "$remote_sha1" ]; then
				echo "No changes in $file on $server."
			else
				echo "$file differs from local copy on $server."
				copy_file=1
			fi
		else
			echo "$file does not exist on $server. Copying file now."
			copy_file=1
		fi

		# copy file if we need to
		if [ "$copy_file" -eq 1 ]; then
			echo "Push $file to $server?"
			read yesno
			if [ "$yesno" == "y" ]; then
				scp $file ${server}:
				if [ $? -ne 0 ]; then
					echo "Errors pushing $file to $server."
					exit 255
				fi

				ssh ${server} "echo $password | sudo -S mv $file $targetDir; sudo chmod 755 $targetDir/$file; if [ -f /usr/local/bin/servers ]; then sudo chmod 644 /usr/local/bin/servers; fi; sudo chown root:root $targetDir/$file"
				if [ $? -ne 0 ]; then
					echo "Errors pushing $file to $server."
					exit 255
				fi
			else
				echo "Skipping $file push to $server."
			fi
		fi
	else
		echo "Missing $file. Croak."
		exit 255
	fi

}

###########################################################################
### start with source push scripts (running on management server for QA ###

for file in $sourcePushScripts; do
	verifyAndPush "$file" "$pushScriptsServer"
done

###########################################
### push scripts living on live servers ###

for file in $sourceCheckoutScripts; do
	for server in ${ALL_APP_SERVERS}; do
		verifyAndPush "$file" "$server"
	done
done

exit 0
