#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Deploy a new VirtualBox VM as a Salt minion."
	echo "Usage:

`basename $0` -n <name of vm>"
	exit 255
}

# get command-line args
while getopts "n:" OPTION; do
	case $OPTION in
		n) servername="$OPTARG";;
		*) usage;;
	esac
done

# ensure argument was passed
if [ -z "${servername}" ]; then
  usage
fi

# deploy
vboxmanage clonevm CentOS\ Template --name ${servername} --register
if [ $? -eq 0 ]; then
  vboxmanage guestproperty set ${servername} GuestName ${servername}
  if [ $? -eq 0 ]; then
    vboxmanage startvm ${servername} --type headless
  else
    echo "error setting guestproperty - exiting."
  fi
else
  echo "error cloning VM - exiting."
fi

exit 0

