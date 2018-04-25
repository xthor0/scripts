#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Add user to host(s)."
	echo "Usage:

`basename $0` [ -a ] -u username -h host[,host1,host2]
-d: Give the user admin rights (usually adds to Wheel group)
multiple hosts can be specified on the command-line but must be separated by only commas."
	exit 255
}

# get command-line args
while getopts "au:h:P:" OPTION; do
	case $OPTION in
		a) admin=1;;
		u) newusername=${OPTARG};;
		h) target=${OPTARG};;
		P) passwd=${OPTARG};;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "${newusername}" -o -z "${target}" ]; then
	usage
fi

# get the user's sudo password
while [ -z "${sudopw}" ]; do
	read -s -p "Please enter your sudo password: " sudopw
done

#########
### BEGIN
#########

# function to log in to remote host and add the user
function addRemoteUser() {
	# verify we can ssh to the remote host and that we have sudo
	ssh ${1} "echo ${sudopw} | sudo -S whoami >& /dev/null"
	if [ $? -eq 0 ]; then
		echo -n "${1}: "
		ssh ${1} "
			# is this machine joined to the domain?
			sid=\"\`wbinfo -n 'domain admins' 2> /dev/null\`\"
			if [ -z \"\$sid\" ]; then
				# not on a domain
				# does the user exist?
				uid=\"\`id -u $newusername 2> /dev/null\`\"
				if [ -z \"\$uid\" ]; then
					# add the user
					echo $sudopw | sudo -S /usr/sbin/adduser $newusername
					if [ \$? -eq 0 ]; then
						# change the password
						echo $passwd | sudo passwd --stdin $newusername >& /dev/null
						if [ \$? -eq 0 ]; then
							# if admin user, add to wheel group
							if [ -n \"$admin\" ]; then
								sudo /usr/sbin/usermod -aG wheel $newusername
								if [ \$? -eq 0 ]; then
									echo \"$newusername successfully added.\"
								else
									echo \"Error adding $newusername to wheel group.\"
								fi
							else
								echo \"$newusername successfully added.\"
							fi
						else
							echo \"Error setting password for $newusername.\"
						fi
					else
						echo \"error adding $newusername.\"
					fi
				else
					echo \"$newusername already exists.\"
				fi
			else
				# on a domain
				echo \"\$HOSTNAME is joined to the domain -- users need to be added through Active Directory.\"
			fi
		" # END SSH SESSION
	else
		echo "Error running sudo command on ${1} -- verify you have sudo rights."
	fi
}

# generate password
if [ -z "${passwd}" ]; then
	if ! [ -x `which pwgen` ]; then
		echo "pwgen not found in path. You must install pwgen for this script to work."
		exit 255
	fi
	passwd="`pwgen -c -n 9 1`"
fi

# print out the information
echo
echo "Username: ${newusername}"
echo -n "Admin rights: "
if [ -z "${admin}" ]; then
	echo "NO"
else
	echo "YES"
fi
echo "Password: ${passwd}"
echo

# parse targets and feed them through function
if [ `echo "${target}" | grep -c ,` -eq 0 ]; then
	addRemoteUser ${target}
else
	for host in `echo ${target} | tr , " "`; do
		addRemoteUser ${host}
	done
fi

# end of script
exit 0
