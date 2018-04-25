#!/bin/sh

# source in server list
srvList="/usr/local/bin/servers"
[ -f $srvList ] && . $srvList

if [ -z "${APP_SERVERS}" ]; then
	echo "Missing APP_SERVERS variable. Submit a helpdesk ticket, this script is broken."
	exit 255
fi

svnUrl="http://svn.datamark.com/itscripts"
localPath="/usr/local/bin"
script="anemone_live_setup.sh"

ME=${SUDO_USER}
if [ -z ${ME} ]; then
	ME=$(whoami)
fi

count=0
while [ -z ${SVNPW} ]; do
	if [ ${count} -ne 0 ]; then
		echo "You must enter a password."
	fi
	
	echo "Please enter your sudo/subversion password: "
	read -s SVNPW
	let count+=1
done

for server in ${APP_SERVERS}; do
	ssh $server "
		TMPFILE=\$(mktemp)
		svn --username $ME --password $SVNPW cat ${svnUrl}/${script} >> \$TMPFILE
		if [ \$? -ne 0 ]; then
			echo \"Error fetching file from svn. Dying now.\"
			rm -f \$TMPFILE
			exit 255
		fi

		if [ -f ${localPath}/${script} ]; then
			# get the sha of the local file
			localSha=\"\`cat ${localPath}/${script} | sha1sum\`\"
			newSha=\"\`cat \$TMPFILE | sha1sum\`\"
			
			if [ \"\$localSha\" == \"\$newSha\" ]; then
				push=0
			else
				push=1
			fi
		else
			push=1
		fi

		# do we push?
		if [ \$push -eq 0 ]; then
			echo \"$script in SVN and on \$HOSTNAME are the same. No push needed.\"
		else
			echo \"Pushing $script to \$HOSTNAME...\"
			echo $SVNPW | sudo -S cp \$TMPFILE ${localPath}/${script}
			if [ \$? -eq 0 ]; then
				sudo chown root:root ${localPath}/${script}
				if [ \$? -eq 0 ]; then
					sudo chmod 755 ${localPath}/${script}
					if [ \$? -eq 0 ]; then
						sudo chcon -t bin_t ${localPath}/${script}
						if [ \$? -eq 0 ]; then
							retval=0
						else
							retval=1
						fi
					else
						retval=1
					fi
				else
					retval=1
				fi
			else
				retval=1
			fi
			
			if [ \$retval -eq 0 ]; then
				echo \"$script successfully pushed to \$HOSTNAME.\"
				rm -f \$TMPFILE
				exit 0
			else
				echo \"Error copying ${script} to ${localPath}.\"
				exit 255
			fi
		fi
	" # END OF SSH COMMAND
	
	if [ $? -ne 0 ]; then
		echo "Error pushing $script to $server. Exiting..."
		exit 255
	fi
done

exit 0	