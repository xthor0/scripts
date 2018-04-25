#!/bin/sh

plugin=$1
server=$2

if [ -z "$plugin" ]; then
	echo "Must specify plugin name as argument."
	exit 255
fi

if [ -z "$server" ]; then
	echo "Must specify server name as argument."
	exit 255
fi

while [ -z "$password" ]; do
	echo "Please enter your sudo password."
	read -s password
done

if [ -f $plugin ]; then
	filename_plugin=`basename $plugin`
	scp $plugin $server:
	if [ $? -eq 0 ]; then
		ssh $server "
			echo $password | sudo -S mv $filename_plugin /usr/lib/nagios/plugins/
			if [ -f /usr/lib/nagios/plugins/$filename_plugin ]; then
				sudo chown root:root /usr/lib/nagios/plugins/$filename_plugin
				if [ \$? -ne 0 ]; then
					echo \"Error changing the ownership of /usr/lib/nagios/plugins/$filename_plugin.\"
					exit 255
				fi
			else
				echo \"Missing /usr/lib/nagios/plugins/$filename_plugin on \$HOSTNAME.\"
				exit 255
			fi

			sudo chmod 755 /usr/lib/nagios/plugins/$filename_plugin
			if [ \$? -ne 0 ]; then
				echo \"Error changing permissions of /usr/lib/nagios/plugins/$filename_plugin.\"
				exit 255
			fi

			sudo chcon user_u:object_r:bin_t /usr/lib/nagios/plugins/$filename_plugin
			if [ \$? -ne 0 ]; then
				echo \"Error changing SELinux context of /usr/lib/nagios/plugins/$filename_plugin.\"
				exit 255
			fi
		" #END SSH SESSION TO $server
		if [ $? -eq 0 ]; then
			echo "$filename_plugin pushed to $server successfully."
		else
			echo "Error pushing $filename_plugin to $server."
			exit 255
		fi
	fi
else
	echo "Can't find $filename_plugin."
	exit 255
fi

exit 0
