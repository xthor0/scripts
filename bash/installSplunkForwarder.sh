#!/bin/bash

# check args
if [ -n "$1" ]; then
	# any argument passed to this script means it's not interactive...
	noninteractive=0
fi

# if splunk is already installed, we die here
if [ -d /opt/splunkforwarder ]; then
	echo "Splunk is already installed!"
	
	# check forwarders
	fwcount=`/opt/splunkforwarder/bin/splunk list forward-server -auth admin:changeme | grep -A1 'Active forwards:' | grep copenhagen101 | wc -l`
	if [ $fwcount -eq 1 ]; then
		# some machines weren't properly configured -- if they weren't, we need to reconfigure them to forward to the DNS alias
		echo "Correcting forwarding address..."
		/opt/splunkforwarder/bin/splunk add forward-server splunk.datamark.com:9999 -auth admin:changeme
		/opt/splunkforwarder/bin/splunk remove forward-server copenhagen101.datamark-inc.com:9999 -auth admin:changeme
	fi
	
	# check for init entry
	/sbin/chkconfig --list splunk >&/dev/null
	if [ $? -eq 1 ]; then
		echo "Making Splunk start at boot..."
		/opt/splunkforwarder/bin/splunk enable boot-start
		/sbin/chkconfig --add splunk
	fi
	
	# cleanup and exit
	rm $0
	exit 255
fi

# install splunk
yum -y install splunkforwarder
if [ $? -ne 0 ]; then
	echo "Error installing splunk forwarder. Exiting."
	exit 255
fi

# check the size of /var/log before proceeding -- if over 1GB throw an alert
size=`du -s /var/log | awk '{ print $1 }'`
if [ $size -ge 1048576 ]; then
	if [ -z "$noninteractive" ]; then
		while [ -z "$answer" ]; do
			echo "WARNING: /var/log size is greater than 1GB. Proceed? (y/n)"
			read answer
		done
		yesno="`echo $answer | tr [:upper:] [:lower:]`"
	
		if [ "$yesno" == "y" -o "$yesno" == "yes" ]; then
			echo "Proceeding with install..."
		else
			echo "Exiting!"
			exit 255
		fi
	else
		echo "WARNING: /var/log size is greater than 1GB. (pausing for 10 seconds)"
		sleep 10
	fi
fi
	
# add lines to the inputs.conf
if [ -d /var/log/httpd ]; then
	echo "
# apache logs
[monitor:///var/log/httpd/*]
sourcetype = access_log

" >> /opt/splunkforwarder/etc/apps/SplunkUniversalForwarder/default/inputs.conf
fi

# is this a MySQL box with bin logging enabled?
if [ -d /var/log/mysql ]; then
	echo "This is a MySQL server with bin logging turned on... excluding bin logs."
	shorthostname="`hostname | cut -d \. -f 1`"
	echo "
# all syslogs
[monitor:///var/log]
sourcetype = syslog
blacklist = ${shorthostname}-(bin|relay)\.[0-9]*
" >> /opt/splunkforwarder/etc/apps/SplunkUniversalForwarder/default/inputs.conf
else
	echo "
# all syslogs
[monitor:///var/log]
sourcetype = syslog
" >> /opt/splunkforwarder/etc/apps/SplunkUniversalForwarder/default/inputs.conf
fi

# start splunk
/opt/splunkforwarder/bin/splunk start --accept-license
if [ $? -ne 0 ]; then
	echo "Error starting splunk forwarder. Exiting."
	exit 255
fi

# add forwarding server
/opt/splunkforwarder/bin/splunk add forward-server splunk.datamark.com:9999 -auth admin:changeme
if [ $? -ne 0 ]; then
	echo "Error adding splunk forwarder configuration. Exiting."
	exit 255
fi

# add splunk to startup config
/opt/splunkforwarder/bin/splunk enable boot-start
/sbin/chkconfig --add splunk

# end!
echo "Splunk forwarder has been installed and configured successfully!"

# delete myself
rm $0
exit 0
