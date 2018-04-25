#!/bin/bash

# get server list
. /usr/local/bin/servers

# START
for server in ${SERVERS}; do
	ssh ${server} "
		if [ \`grep sbin .bash_profile | wc -l\` -eq 0 ]; then
			sed -i 's/^PATH=.*/PATH=\$PATH:\/sbin:\/usr\/sbin:\$HOME\/bin/g' .bash_profile
			echo \"\$HOSTNAME: .bash_profile modified.\"
		else
			echo \"\$HOSTNAME: .bash_profile not modified.\"
		fi
	" # End SSH session
done

exit 0
