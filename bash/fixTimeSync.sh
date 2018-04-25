#!/bin/bash

servers="$*"

if [ -z "$servers" ]; then
	echo "You forgot to provide a server or list of servers on the command line."
	exit 255
fi

for server in $servers; do
	echo "$server =======>"
	ssh -t $server "
		# first, disable syncing VM clock with physical host
		echo Hu3v05C@m313r05 | sudo -S vmware-toolbox-cmd timesync disable
		if [ \$? -ne 0 ]; then
			echo \"Error disabling vmware time sync\"
			exit 255
		fi
		
		# make mods to NTP configuration
		grep 'tinker panic 0' /etc/ntp.conf >& /dev/null
		if [ \$? -eq 1 ]; then
			echo Hu3v05C@m313r05 | sudo -S sed -i '1i\tinker panic 0' /etc/ntp.conf
			if [ \$? -ne 0 ]; then
				echo \"Error modifying ntp.conf\"
				exit 255
			fi
		else
			echo \"tinker panic entry already present in ntp.conf\"
		fi
		
		sudo sed -i 's/^server[[:space:]]127.127.1.0/#&/g' /etc/ntp.conf
		if [ \$? -eq 0 ]; then
			sudo sed -i 's/^fudge[[:space:]]127.127.1.0/#&/g' /etc/ntp.conf
			if [ \$? -eq 0 ]; then
				sudo /sbin/service ntpd stop
				if [ -x /sbin/ntpdate ]; then
					sudo /sbin/ntpdate 0.centos.pool.ntp.org
					retval=\$?
				else
					sudo /usr/sbin/ntpdate 0.centos.pool.ntp.org
					retval=\$?
				fi
				if [ \$retval -eq 0 ]; then
					echo Hu3v05C@m313r05 | sudo -S /sbin/service ntpd start
					sudo /sbin/chkconfig ntpd on
					echo \"Time configuration modified successfully.\"
				else
					echo \"Error modifying time config.\"
				fi
			else
				echo \"Error modifying ntp.conf\"
			fi
		else
			echo \"Error modifying ntp.conf\"
		fi
	" # END SSH SESSION
	echo "<=========="
done

exit 0
