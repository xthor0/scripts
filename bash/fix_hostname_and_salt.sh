#!/bin/bash

# this is ugly and hacky - but let's give it a shot
while getopts "h:" opt; do
	case $opt in
		h)
			targethost=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit 255
			;;
	esac
done

# did we get the required arguments?
if [ -z "$targethost" ]; then
	echo "You must specify the target host with -h"
	exit 255
fi

# first - open ssh session to fqdn in question, and get the current hostname
remotehostname=$(ssh ${targethost} "echo \$HOSTNAME")
if [ "$remotehostname" == "$targethost" ]; then
	echo "Hostname is already set correctly. We're done here."
	exit 0
fi

# targethost is an fqdn and it SHOULD be all lowercase - let's make sure that
# the proposed hostname matches
# check it for stormwind.local
echo $remotehostname | grep -q stormwind.local
if [ $? -eq 1 ]; then
	echo "Current hostname does not contain 'stormwind.local'"
	remotehostname=${remotehostname}.stormwind.local
fi

# now, remotehostname should match targethost...
newhostname=$(echo $remotehostname | tr [:upper:] [:lower:])
if [ "$targethost" != "$newhostname" ]; then
	echo "Error: ${targethost} and ${newhostname} don't match, but they should."
	exit 9
fi

echo "Current hostname: ${remotehostname}"
echo "Proposed hostname: ${newhostname}"

echo "Are you sure you want to proceed with this change?"
echo
read -n 1 -s -r -p "Press any key to continue (or CTRL-C to exit)"
#read -s -p "Press any key to continue (or CTRL-C to exit)"

# order of operations...
# 1. shut down salt minion on target
# 2. change /etc/salt/minion_id on target
# 3. rename the minion key on the salt master
# 4. start salt minion on target

# make sure that the master has a key file...
echo "Checking for presence of key file on Salt master:"
echo "/etc/salt/pki/master/minions/${remotehostname}"
ssh slc-prdappslt01.stormwind.local sudo test -f /etc/salt/pki/master/minions/${remotehostname}
if [ $? -eq 1 ]; then
	echo "Uh, there is no key file for this minion!"
	exit 255
fi

# shut down salt minion
echo "Stopping salt-minion on ${targethost}..."
ssh -t ${targethost} sudo systemctl stop salt-minion
if [ $? -ne 0 ]; then
	echo "Error: 'systemctl stop salt-minion' command exited non-zero"
	exit 9
fi

# change the minion_id
echo "Changing minion_id on ${targethost}..."
ssh -t ${targethost} "echo ${newhostname} | sudo tee /etc/salt/minion_id"
if [ $? -ne 0 ]; then
	echo "Error changing minion_id -- Investigate!!"
	exit 8
fi

# rename the key file on the master
echo "Renaming key file on Salt master..."
ssh slc-prdappslt01.stormwind.local sudo mv /etc/salt/pki/master/minions/${remotehostname} /etc/salt/pki/master/minions/${newhostname}
if [ $? -ne 0 ]; then
	echo "Error renaming key file on master -- please investigate!"
	echo "Command executed:"
	echo
	echo "sudo mv /etc/salt/pki/master/minions/${remotehostname} /etc/salt/pki/master/minions/${newhostname}"
	exit 9
fi

# make sure the key file is in place on the master
echo "Checking for key file on Salt master..."
ssh slc-prdappslt01.stormwind.local sudo test -f /etc/salt/pki/master/minions/${newhostname}
if [ $? -eq 1 ]; then
	echo "Can't find minion key file on Salt master:"
	echo /etc/salt/pki/master/minions/${newhostname}
	exit 255
fi

# restart the minion
echo "Starting salt-minion on ${targethost}..."
ssh -t ${targethost} sudo systemctl start salt-minion
if [ $? -ne 0 ]; then
	echo "Error: 'systemctl start salt-minion' command exited non-zero"
	exit 9
fi

# set the hostname on the minion, too
# this requires some fun logic - it's different for cent6 than cent7
echo "Changing hostname on ${targethost}..."
release=$(ssh -t ${targethost} cat /etc/redhat-release | awk '{ print $4 }' | cut -d \. -f 1)
if [ "${release}" == "(Final)" ]; then
	# centos 6
	ssh -t ${targethost} sudo sed -i "s/^HOSTNAME=${remotehostname}/HOSTNAME=${targethost}/g" /etc/sysconfig/network
	if [ $? -eq 0 ]; then
		ssh -t ${targethost} sudo hostname ${targethost}
		if [ $? -ne 0 ]; then
			echo "Error executing \'hostname ${targethost}\' on ${targethost} -- investigate!"
		fi
	else
		echo "Error running sed command to modify /etc/sysconfig/network -- investigate!"
	fi
elif [ "${release}" == "7" ]; then
	# centos 7
	ssh -t ${targethost} sudo sed -i "s/^hostname=${remotehostname}/hostname=${targethost}/g" /etc/sysconfig/network
	if [ $? -eq 0 ]; then
		ssh -t ${targethost} sudo hostnamectl set-hostname ${targethost}
		if [ $? -ne 0 ]; then
			echo "Error running \'hostnamectl set-hostname\' on ${targethost} -- investigate!"
		fi
	else
		echo "Error running sed command against /etc/sysconfig/network -- investigate!"
	fi
fi

# do this on target just to be safe...
ssh -t ${targethost} sudo sed -i "s/${remotehostname}/${targethost}/g" /etc/hosts
if [ $? -ne 0 ]; then
	echo "Error running sed command to fix /etc/hosts -- investigate!"
fi

# make sure the Salt master can communicate with the minion
ssh slc-prdappslt01.stormwind.local sudo salt ${newhostname} test.ping
if [ $? -eq 0 ]; then
	echo "Hostname change was a success!"
else
	echo "Uh-oh... salt exited with a non-zero exit code! Investigate."
fi

exit 0
