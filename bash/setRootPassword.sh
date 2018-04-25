#!/bin/bash

# source in list of servers
. /usr/local/bin/servers

echo "======== WARNING ======="
echo "This script will set a new password on all the following servers: "
echo $SERVERS
echo "Proceed? (y/n)"
read -s yesno
if [ "$yesno" != "y" ]; then
	echo "Exiting..."
	exit 255
fi
echo

# prompt for required information
while [ -z "$sudopw" ]; do
	echo "Please enter your sudo password: "
	read -s sudopw
done
echo "Thank you."
echo

while [ -z "$newrootpw" ]; do
	echo "Please enter the new root password you would like to assign to the servers listed above:"
	read -s newrootpw
done
echo

echo "============ PLEASE CONFIRM ================"
echo
echo "This script will change the root password to"
echo "--> ${newrootpw} <--"
echo "on the following servers: "
echo
echo $SERVERS
echo
echo "Please type GOFORIT! to proceed:"
read goforit
if [ "$goforit" != "GOFORIT!" ]; then
	echo "Wuss."
	exit 255
fi

# do it
for server in $SERVERS; do
	ssh -t $server "
		# do this once so we're not doing a double echo
		echo $sudopw | sudo -S whoami &> /dev/null
		if [ \$? -eq 0 ]; then
			echo $newrootpw | sudo /usr/bin/passwd --stdin root &> /dev/null
			if [ \$? -eq 0 ]; then
				[ -f /root/.ssh/authorized_keys ] && echo \"SSH keys for root found on \$HOSTNAME.\"
				echo \"\$HOSTNAME: Completed\"
			else
				echo \"Non-zero exit status of passwd on \$HOSTNAME.\"
			fi
		else
			echo \"Non-zero exit status of sudo command on \$HOSTNAME.\"
		fi
	" # END SSH
done

# end!
echo "Completed."
exit 0
