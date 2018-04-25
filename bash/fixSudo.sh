#!/bin/bash

# source in list of servers
#. /usr/local/bin/servers
SERVERS="compton.datamark.com fredonia.datamark.com"

# root password required
while [ -z "${rootpass}" ]; do
	read -s -p "Please enter root password: " rootpass
done
echo

SSHCOMMAND="echo -n \\\"\\$HOSTNAME:\\\"
	# are the desired changes already made?
	if [ \\\`grep '\\\\!requiretty' /etc/sudoers | wc -l\\\` -eq 0 ]; then
		# is requiretty already disabled? if so, turn it back on
		if [ \\\`grep '^#Defaults.*requiretty' /etc/sudoers | wc -l\\\` -eq 1 ]; then
			echo -n \\\"enabling requiretty for all users... \\\"
			sed -i.bkp 's/^#Defaults.*requiretty/Defaults	requiretty/g' /etc/sudoers
			echo -n \\\"Done. \\\"
		fi

		# is this server tied to AD?
		uid=\\\`id bbrown | awk '{print \\$1}' | sed 's/[^0-9]*//g'\\\`
		if [ \\${uid} -eq 10975 ]; then
			# this server is authenticating to AD
			echo -n \\\"AD auth on, disabling tty for domain admins... \\\"
			sed -i '/Defaults	requiretty/aDefaults:%domain\\\ admins	\\\!requiretty' /etc/sudoers
			echo \\\"Done.\\\"
		else
			# this server is using local authentication
			echo -n \\\"local auth, disabling tty for wheel...\\\"
			sed -i '/Defaults	requiretty/aDefaults:%wheel	\\\!requiretty' /etc/sudoers
			echo \\\"Done.\\\"
		fi
	else
		echo \\\"Sudo requiretty changes already present.\\\"
	fi
	\\\" # END SSH"

# do it
for server in $SERVERS; do
	expect -c "set timeout -1;\
	spawn ssh root@$server \"$SSHCOMMAND\";\
	expect *password:*;\
	send -- $rootpass\r;\
	interact;"
done

# end!
echo "End of `basename $0`."
exit 0
