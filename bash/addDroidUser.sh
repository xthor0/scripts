#!/bin/bash

# get list of servers
. /usr/local/bin/servers

# get sudo password
echo "Please enter your sudo password: "
read -s sudopw

# check it
if [ -z "$sudopw" ]; then
	echo "Hey, stupid, you didn't type your sudo password."
	exit 255
fi

# get to it
echo $server
for server in $WEB_SERVERS; do
	ssh $server "
		# add 'other' permissions on /var/log/httpd
		echo \"Changing permissions of /var/log/httpd...\"
		echo $sudopw | sudo -S chmod o+rx /var/log/httpd
		if [ \$? -eq 0 ]; then
			echo \"Done.\"
		else
			echo \"Error!\"
		fi

		# see if droid user already exists, create if it doesn't
		id droid >& /dev/null
		if [ \$? -eq 1 ]; then
			sudo /usr/sbin/useradd -u 1000 droid
			if [ \$? -eq 0 ]; then
				echo \"Droid user created on \$HOSTNAME.\"
			else
				echo \"Could not create droid user on \$HOSTNAME.\"
			fi
		else
			echo \"Droid account already exists on \$HOSTNAME.\"
		fi

		# set the password
		echo 88jd078K7s3M | sudo /usr/bin/passwd --stdin droid
	" # END OF SSH SESSION
done

exit 0
