#!/bin/bash

## ORIGINAL COMMAND RUN
## yum -y remove splunkforwarder && rm -rf /opt/splunkforwarder /etc/init.d/splunk && userdel splunk

# get host from command-line
remotehost=$1

# set a variable
cleaned=0

ssh $remotehost "
	# check for splunk RPM
	rpm -qi splunkforwarder
	if [ \$? -eq 0 ]; then
		yum -y remove splunkforwarder
		cleaned=1
	fi

	# remove the splunk user if it exists
	if [ \`grep ^splunk /etc/passwd | wc -l\` -ne 0 ]; then
		/usr/sbin/userdel -r splunk
		cleaned=1
	fi

	# make sure files and directories were properly cleaned up
	if [ -d /opt/splunkforwarder ]; then
		rm -rf /opt/splunkforwarder
		cleaned=1
	fi

	if [ -f /etc/init.d/splunk ]; then
		rm -f /etc/init.d/splunk
		cleaned=1
	fi

	if [ \$cleaned -eq 0 ]; then
		echo \"Splunk was not found on this system.\"
	else
		echo \"Splunk has been removed from this system.\"
	fi
" ## END SSH SESSION

exit 0
