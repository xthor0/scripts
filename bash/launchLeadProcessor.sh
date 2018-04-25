#!/bin/sh

procCount=$1
admins="ben.brown@datamark.com"
launchCMD="php /srv/stingray/www/cli/lead_processor.php"
logFile="/srv/stingray/www/logs/lead_processor.log"

# logging
#function log($message) {
#	echo "[`basename $0`: `date +%x\ %X`] $message" >> $logFile
#}

# usage
function usage() {
	message="`basename $0` was launched without any arguments!"
	echo $message | mail -s "Error" $admins
	# eventually I will write a log function to log errors
	# log $message
	exit 255
}

if [ -z "$procCount" ]; then
	usage
fi

# make sure argument passed is a 2-digit number
if [ `echo $procCount | grep [0-9][0-9] | wc -c` -eq 0 ]; then
	usage
fi

# kick off!
for i in `seq 1 $procCount`; do
	# check for running lead_processor
	if [ `ps ax | grep "$launchCMD $i$" | grep -v grep | wc -l` -eq 0 ]; then
		# log "Launching lead processor $i..."
		$launchCMD $i &
		# for testing
		#echo "$launchCMD $i"
		sleep 15
	fi
done

exit 0
