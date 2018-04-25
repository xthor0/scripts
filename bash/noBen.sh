#!/bin/bash

# source in list of servers
#. /usr/local/bin/servers
SERVERS="devanaheim.datamark.com fredonia.datamark.com"

# prompt for required information
while [ -z "$sudopw" ]; do
	echo "Please enter your sudo password: "
	read -s sudopw
done
echo "Thank you."
echo

# generate a new, secure temporary password
newpasswd="`pwgen -s 25 1 2>/dev/null`"
if [ -z "${newpasswd}" ]; then
	echo "There is a problem generating a secure password. Exiting..."
	exit 255
else
	echo "Secure password: ${newpasswd}"
fi

# do it
for server in $SERVERS; do
	ssh $server "
		# do this once so we're not doing a double echo
		echo $sudopw | sudo -S whoami &>/dev/null
		if [ \$? -eq 0 ]; then
			if [ \`grep ^bcarner /etc/passwd | wc -l\` -eq 0 ]; then
				echo \"\$HOSTNAME: bcarner not found.\"
				exit 5
			fi

			echo $newpasswd | sudo /usr/bin/passwd --stdin bcarner &>/dev/null
			if [ \$? -eq 0 ]; then
				[ -f /home/bcarner/.ssh/authorized_keys ] && sudo rm /home/bcarner/.ssh/authorized_keys
				sudo /usr/sbin/usermod -L bcarner
				[ -f /var/spool/cron/bcarner ] && echo \"Crontab for bcarner found on \$HOSTNAME.\"
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
