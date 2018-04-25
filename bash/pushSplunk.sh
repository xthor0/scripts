#!/bin/bash

servers="$*"

script="/cygdrive/c/Users/bbrown/Dropbox/projects/scripts/installSplunkForwarder.sh"

while [ -z "$sudopw" ]; do
	echo "Please enter your sudo password: "
	read -s sudopw
done

for server in $servers; do

	echo
	echo "===================="
	echo $server
	echo "===================="
	
	scp $script $server:
	if [ $? -eq 0 ]; then
		ssh $server "echo $sudopw | sudo -S /home/bbrown/installSplunkForwarder.sh nointeractive"
	else
		echo "Error copying install script to $server."
	fi

done