#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Change Linux username from one name to another on <hostname>."
	echo "This will change the username AND move the home directory to the new username."
	echo "Usage:

`basename $0` -u <existing username> -n <new username> -h <hostname> [ -P <sudo password> ]"
	exit 255
}

# get command-line args
while getopts "n:u:h:" OPTION; do
	case $OPTION in
		n) newUser="$OPTARG";;
		u) oldUser="$OPTARG";;
		h) targetHost="$OPTARG";;
		P) sudoPassword="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$newUser" -o -z "$oldUser" -o -z "$targetHost" ]; then
	usage
fi

# prompt for sudo password if not specified on command-line
while [ -z "$sudoPassword" ]; do
	echo "Please enter your sudo password: "
	read -s sudoPassword
done

# do it to it
ssh $targetHost "
	# verify the user exists on this server
	if [ \`grep $oldUser /etc/passwd | wc -l\` -eq 1 ]; then
		echo \"User $oldUser found...\"
		# change the username
		echo $sudoPassword | sudo -S /usr/sbin/usermod -l $newUser $oldUser
		if [ \$? -eq 0 ]; then
			echo \"Username changed successfully.\"
			sudo /usr/sbin/groupmod -n $newUser $oldUser
			if [ \$? -eq 0 ]; then 
				echo \"Group changed successfully.\"
				sudo /usr/sbin/usermod -d /home/$newUser -m $newUser
				if [ \$? -eq 0 ]; then
					echo \"Home directory moved successfully.\"
					if [ -x /etc/init.d/smb -a \`ps ax | grep smb | grep -v grep | wc -l\` -ne 0 ]; then
						sudo /sbin/service smb restart
					fi
				else
					echo \"Error moving home directory to /home/$newUser.\"
					exit 255
				fi
			else
				echo \"Error changing group.\"
				exit 255
			fi
		else
			echo \"Error renaming $oldUser to $newUser.\"
			exit 255
		fi
	else
		echo \"$oldUser not found on \$HOSTNAME.\"
		exit 255
	fi
" # DO NOT REMOVE

echo "$oldUser successfully migrated to $newUser on $targetHost."
exit 0
