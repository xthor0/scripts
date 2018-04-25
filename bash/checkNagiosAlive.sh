#!/bin/sh

nagiosIP="192.168.251.10"
check_nrpe="/usr/lib/nagios/plugins/check_nrpe"
admins="xthor@xthorsworld.com kendall@american-ins.com"
log="$HOME/nagiosCheck.log"
templog="/tmp/checknagios-$RANDOM.email"
statefile="$HOME/.checknagios-state"

# do we have the necessary libraries?
if ! [ -x $check_nrpe ]; then
	message="Missing check_nrpe on $HOSTNAME."
	echo $message
	echo $message | mail -s "$0: Error" $admins
	exit 255
fi

# get state
if [ -f $statefile ]; then
	. $statefile
else
	echo "STATE=OK" > $statefile
	. $statefile
fi

# verify state
if [ -z "$STATE" ]; then
	echo "Ben: You screwed up! Fix $0 on $HOSTNAME." | mail -s "Idiot." xthor@xthorsworld.com
	exit 255
fi

# timestamp
date > $templog

# check to make sure Nagios is running
$check_nrpe -H $nagiosIP -c check_nagios >> $templog
if [ $? -eq 0 ]; then
	echo "All is well... sleeping..." >> $templog
	CURRENT_STATE="OK"
else
	echo "Error... checking to see if $nagiosIP is down..." >> $templog
	/bin/ping -c5 -w5 -q $nagiosIP >> $templog 2>&1
	if [ $? -eq 0 ]; then
		echo "$nagiosIP is alive, but Nagios is not running." >> $templog
	else
		echo "$nagiosIP is down!" >> $templog
	fi
	CURRENT_STATE="ERROR"
fi

# is this a state change?
if [ "$STATE" != "$CURRENT_STATE" ]; then
	if [ "$STATE" == "ERROR" ]; then
		NEWSTATE="RECOVERY"
	else
		NEWSTATE="PROBLEM"
	fi

	cat $templog | mail -s "Nagios: $NEWSTATE" $admins
	echo "STATE=$CURRENT_STATE" > $statefile
fi

# put the templog in the REAL log...
cat $templog >> $log
echo "===========================" >> $log

exit 0

