#!/bin/bash

LASTRUN=$(/bin/date +%Y/%m/%d\ %l:%M\ %p)
sudo /usr/bin/apt-get -qqy update
if [ $? -eq 0 ]; then
	NUMOFUPDATES=$(/usr/bin/aptitude search "~U" | wc -l)
else
	NUMOFUPDATES="Error"
fi

echo "Last check: ${LASTRUN}"
echo "Available updates: ${NUMOFUPDATES}"
exit 0
