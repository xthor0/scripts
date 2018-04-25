#!/bin/bash

host=$1
sound="/usr/share/sounds/gnome/default/alerts/sonar.ogg"

if [ -z "$host" ]; then
	echo "Must provide a hostname or IP address on the command-line."
	exit 255
fi

control_c()
{
	echo -en "\n*** Exiting ***\n"
	exit 0
}
       
# trap keyboard interrupt (control-c)
trap control_c SIGINT

while true; do
	ping -c1 -w1 -q $host >& /dev/null
	if [ $? -eq 0 ]; then
		echo "$host: alive"
		play -q $sound
	else
		echo "$host: dead"
	fi
	sleep 1
done

# end
exit 0
