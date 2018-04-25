#!/bin/bash

# make sure that the hostname is not "salt-cloud-template"
# if it is, this is an indication that the salt-cloud customization module didn't work correctly
hostname | grep -q salt-cloud-template
if [ $? -eq 0 ]; then
	echo "Hostname was not set correctly by salt-cloud deployment."
	echo "If this was not intentional, this VM will not function correctly."
	read -n1 -s -r -p "Press any key to return to a login screen. " </dev/tty
	#echo "I'll return you to the login screen in 60 seconds."
	#sleep 60
	chvt 1
	exit 255
fi

# hostname is SHORTHOSTNAME, because that's how the Mikes want it organized in VMware
# so, we'll change it to lowercase, and add stormwind.local to the FQDN
newhostname=$(cat /etc/hostname | tr [:upper:] [:lower:])
echo $newhostname | grep -q stormwind.local
if [ $? -eq 0 ]; then
	hostnamectl set-hostname ${newhostname}
	retval=$?
else
	hostnamectl set-hostname ${newhostname}.stormwind.local
	retval=$?
fi

# make sure hostnamectl exited appropriately
if [ $retval -ne 0 ]; then
	echo "Error: hostnamectl failed to set the hostname appropriately."
	echo "There's no reason for me to add it to Salt - this script will exit now."
	read -n1 -s -r -p "Press any key to return to a login screen. " </dev/tty
	chvt 1
	exit 255
fi
 
# regenerate SSH keys
echo "Regenerating SSH keys..."
systemctl stop sshd.service >& /dev/null
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
systemctl start sshd.service >& /dev/null
 
# install Salt from official repos
## TODO: Mirror this to local repo!
echo "Installing salt-minion..."
rpm -ivh https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm 
if [ $? -eq 0 ]; then
	yum -y clean all
	yum -y install salt-minion
	if [ $? -ne 0 ]; then
		echo "Error installing salt-minion - this VM will NOT deploy automatically!"
		read -n1 -s -r -p "Press any key to return to a login screen. " </dev/tty
		chvt 1
		exit 255
	fi
fi

# hosts file still gets created with uppercase... fix it here
cat /etc/hosts | tr [:upper:] [:lower:] > /tmp/hosts && cat /tmp/hosts > /etc/hosts && rm -f /tmp/hosts

# make salt run a highstate on reboot
echo "startup_states: state.highstate" >> /etc/salt/minion

# make Salt start on boot
systemctl enable salt-minion.service

# fix fstab (security permissions)
sed -ie '/\/boot/ s/defaults/defaults,nosuid,noexec,nodev/' /etc/fstab

# pull in latest updates (this kinda sucks because it comes from the internet instead of local, but oh well)
echo "Checking for yum updates..."
yum -y update
if [ $? -eq 0 ]; then
	# make sure this service doesn't run again
	rm -f /usr/local/pl-setup.sh /usr/lib/systemd/system/pl-setup.service /usr/lib/systemd/system/default.target.wants/pl-setup.service

	# clean up old kernels
	/bin/package-cleanup --oldkernels --count=1

	# clean up log files
	/usr/sbin/logrotate –f /etc/logrotate.conf
	/bin/rm –f /var/log/*-???????? /var/log/*.gz
	/bin/rm -f /var/log/dmesg.old
	/bin/rm -rf /var/log/anaconda

	# truncate some logs
	/bin/cat /dev/null > /var/log/audit/audit.log
	/bin/cat /dev/null > /var/log/wtmp
	/bin/cat /dev/null > /var/log/lastlog

	# clean up some other files we don't need
	/bin/rm -f /tmp/* /var/tmp/* /root/.bash_history /root/anaconda-ks.cfg /root/original-ks.cfg

	reboot
fi

# end of script
chvt 1
exit 0
