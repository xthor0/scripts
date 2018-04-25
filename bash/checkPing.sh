#!/bin/sh

if [ -z "$1" ]; then
	echo "You must specify a host to ping on the command-line."
	echo "i.e. `basename $0` 10.5.9.11"
	exit 255
fi

if [ -n "$2" ]; then
	echo "running in loop mode"
fi

host=$1
admin="ben.brown@datamark.com"
temp="/tmp/ping.out.$RANDOM"
mail="/tmp/mail.out.$RANDOM"
sleep=60

# ping function
function pingIt() {
	ping -c5 -w5 -q $host > $temp 2>&1
	if [ $? -ne 0 ]; then
		# mail output to $admin
		echo "Problem pinging $host at `date`." >> $mail
		cat $temp >> $mail
		cat $mail | mail -s "Ping Problem from `hostname` to $host"
	else
		echo "No problems at `date`."
	fi
	rm -f $temp $mail
}

# kick it off
if [ -z "$2" ]; then
	pingIt
else
	while true; do
		pingIt
		sleep $sleep
	done
fi

exit 0
