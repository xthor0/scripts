#!/bin/bash

while true; do
	sleep=0
	florence101check=`snmpwalk -v 1 -c DMark florence101.datamark-inc.com | grep Trusted | wc -l`
	florence102check=`snmpwalk -v 1 -c DMark florence101.datamark-inc.com | grep Trusted | wc -l`
	if [ $florence101check -eq 1 ]; then
		sleep=1
		florence101="Running..."
	else
		florence101="Done!"
	fi

	if [ $florence102check -eq 1 ]; then
		sleep=1
		florence102="Running..."
	else
		florence102="Done!"
	fi

	if [ $sleep -eq 1 ]; then
		echo "Florence101: $florence101 -- Florence102: $florence102. One of them is not done..."
		sleep 30
	else
		echo "SP1 upgrades are done! yay!"
		echo "sp1 upgrades on the Florence servers is finally done..." | mail -s sp1 ben.brown@datamark.com
	fi
done
