#!/bin/sh

success=0
attempts=0
maxattempts=5
sleep=30
while [ ${success} -eq 0 ]; do
	/usr/bin/curl -s -m 60 -u xthor@xthorsworld.com:'**redacted**' 'https://updates.dnsomatic.com/nic/update?' | grep -q '^good'
	if [ $? -eq 0 ]; then
		echo "$0 :: DNS-O-Matic updated successfully"
		success=1
	else
		# try again
		let attempts+=1
		if [ ${attempts} -le ${maxattempts} ]; then
			echo "$0 :: DNS-O-Matic update failed, attempt ${attempts} of ${maxattempts}"
			sleep ${sleep}
		else
			echo "$0 :: DNS-O-Matic maximum updates reached, failed."
			break
		fi
	fi
done

exit 0
