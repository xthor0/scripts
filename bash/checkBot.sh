#!/bin/bash

pidFile=$HOME/pid.dmbot

if [ -f ${pidFile} ]; then
	pid=$(cat $pidFile)
	if [ -n "${pid}" ]; then
		if [ -d /proc/${pid} ]; then
			# assume all is well
			exit 0
		fi
	fi
fi

# if we got here, one of the tests above did not pan out
# so we restart the bot
eggdrop $HOME/eggdrop.conf
exit 0
