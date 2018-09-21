#!/bin/bash

IPLIST="10.15.1.65 10.15.49.43 10.15.27.134 10.15.27.131 10.15.49.42 10.15.27.132 10.15.1.62"
while true; do
	date
	for ip in ${IPLIST}; do
		echo -n "${ip}: "
    STARTTIME=$(date +%s)
		ping -c1 -w1 -q ${ip} >& /dev/null
    retval=$?
    ENDTIME=$(date +%s)
    ELAPSED=$(expr ${STARTTIME} - ${ENDTIME})
		if [ ${retval} -eq 0 ]; then
			echo "OK - time: ${ELAPSED}"
		else
			echo "Error! - time: ${ELAPSED}"
			exit 255
		fi
	done
	echo
	sleep 1
done
