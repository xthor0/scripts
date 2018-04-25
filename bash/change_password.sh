#!/bin/bash

# source in list of servers
[ -f /home/bbrown/svn/itscripts/servers ] && . /home/bbrown/svn/itscripts/servers

if [ -z "${ALL_SERVERS}" ]; then
	echo "Could not obtain appropriate environment variables (ALL_SERVERS)."
	exit 255
fi	

# display usage
function usage() {
        echo "`basename $0`: Change a user's password on a whole shitload of servers."
        echo "Usage:

	`basename $0` -U <username to change> -P <new password> -S <sudo password>"
        exit 255
}

# get command-line args
while getopts "U:P:S:" OPTION; do
        case $OPTION in
               U) PWUSER="$OPTARG";;
	       P) newpassword="$OPTARG";;
	       S) sudopw="$OPTARG";;
               *) usage;;
        esac
done

# prompt for required information
while [ -z "$PWUSER" ]; do
	echo -n "Please enter the username you want to change the password for: "
	read PWUSER
done
echo

while [ -z "$newpassword" ]; do
	echo -n "Please enter the new password for $PWUSER: "
	read newpassword
done
echo

while [ -z "$sudopw" ]; do
	echo -n "Please enter your sudo password: "
	read -s sudopw
done
echo "Thank you."
echo

echo
echo "To verify: "
echo
echo "You want to set $PWUSER's password to $newpassword -- right? (Type YESIMSURE to proceed)"
read -s proceed
if [ "$proceed" == "YESIMSURE" ]; then
	echo "Proceeding..."
	echo
else
	echo "OK, you're not sure."
	exit 255
fi

# do it
for server in $ALL_SERVERS; do
	echo "$server -->"
	ssh -t $server "
		# check UID -- if it's less than 1k, it's a local user
		PWUID=\`id -u $PWUSER\`
		if [ \$PWUID -lt 1000 ]; then
			# do this once so we're not doing a double echo
			echo $sudopw | sudo -S whoami >&/dev/null
			if [ \$? -eq 0 ]; then
				echo $newpassword | sudo /usr/bin/passwd --stdin $PWUSER >&/dev/null
				if [ \$? -eq 0 ]; then
					echo \"\$HOSTNAME: $PWUSER password reset\"
				else
					echo \"Non-zero exit status of passwd on \$HOSTNAME.\"
				fi
			else
				echo \"Non-zero exit status of sudo command on \$HOSTNAME.\"
			fi
		else
			echo \"$PWUSER is a domain user -- no password reset required.\"
		fi
	" # END SSH
done

# end!
echo "Completed."
exit 0
