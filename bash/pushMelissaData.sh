#!/bin/bash

# variables
servers="devseville qa1seville qa2seville stseville lisbon seville madrid barcelona wendover"
tarball="melissa-data-`date +%d_%m_%Y_%S`.tgz"
bkupTarball="melissa-data-bkup-`date +%d_%m_%Y_%S`.tgz"

# display usage
function usage() {
	echo "`basename $0`: Push melissa data updates to servers."
	echo "Usage:

`basename $0` -F /path/to/tarball [ -P sudopassword ]"
	exit 255
}

# get command-line args
while getopts "F:P:H:" OPTION; do
	case $OPTION in
		F) data_file="$OPTARG";;
		P) sudo_password="$OPTARG";;
		H) server="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$data_file" -o -z "$server" ]; then
	usage
fi

if [ -z "$sudo_password" ]; then
	while [ -z "$sudo_password" ]; do
		echo "Please enter your sudo password: "
		read -s sudo_password
	done
fi

# do it
if [ -f "$data_file" ]; then
	echo "Copying files to $server..."
	scp $data_file $server.datamark.com:
	if [ $? -eq 0 ]; then
		echo "Configuring melissadata on $server..."
		ssh $server.datamark.com "
			# back up existing directory
			tar czvf \$HOME/$bkupTarball /var/lib/melissadata
			if [ \$? -eq 0 ]; then
				echo $sudo_password | sudo -S tar zxvf \$HOME/$data_file -C /var/lib/melissadata
				cd /var/lib/melissadata
				sudo chown root:root *
				sudo chcon -t httpd_sys_content_t *
				rm -f \$HOME/$data_file
			else
				echo \"Error backing up existing melissadata installation on \$HOSTNAME.\"
			fi
		" # END SSH SESSION
		echo "Done with $server."
	else
		echo "Error copying file to $server."
	fi
else
	echo "$data_file not found."
fi
exit 0
