#!/bin/bash

# variables
var="var1"

# display usage
function usage() {
	echo "`basename $0`: Install Patchlink Update Agent on remote Linux server."
	echo "Usage:

`basename $0` -h <hostname> -g <group>"
	exit 255
}

# get command-line args
while getopts "h:g:" OPTION; do
	case $OPTION in
		h) targetHost="$OPTARG";;
		g) group="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$targetHost" -o -z "$group" ]; then
	usage
fi

# copy update package to $targetHost
scp ~/WinHome/Desktop/PatchLink_LinuxAgent.tgz $targetHost:/tmp/
if [ $? -ne 0 ]; then
	echo "Error copying agent tarball to $targetHost."
	exit 255
fi

# tell met what host we are working on
echo "Installing on $targetHost..."

# log in and kick it off
ssh $targetHost "
if [ ! -f /tmp/PatchLink_LinuxAgent.tgz ]; then
	echo \"Can't find installation files on $targetHost.\"
	exit 255
else
	if [ -d /usr/local/patchagent ]; then
		echo \"PatchLink Agent has already been installed on \$HOSTNAME.\"
		exit 255
		rm -f /tmp/PatchLink_LinuxAgent.tgz
	fi

	cd /tmp
	tar zxvf PatchLink_LinuxAgent.tgz >& /dev/null
	cd updateagent
	echo \"Hu3v05C@m313r05\" | sudo -S ./installJRE.sh
	if [ \$? -ne 0 ]; then
		echo \"Error installing jre. Exiting...\"
		exit 255
	fi
	tar xvf unixupdateagent.tar >& /dev/null
	echo \"Hu3v05C@m313r05\" | sudo -S ./install -silent -sno DE4E8B57-111D6B7C -p http://seattle.datamark-inc.com -d /usr/local -g $group
	if [ \$? -ne 0 ]; then
		echo \"Error running PatchLink Agent installer.\"
	else
		echo \"Hu3v05C@m313r05\" | sudo -S /sbin/chkconfig patchagent on
		if [ \$? -ne 0 ]; then
			echo \"Error making patchagent start at boot.\"
		else
			echo \"PatchLink Agent installed successfully on \$HOSTNAME.\"
		fi
	fi

	cd /tmp
	rm -rf updateagent PatchLink_LinuxAgent.tgz
fi
" # DO NOT REMOVE!
exit 0
