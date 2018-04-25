#!/bin/sh

# logs
log=$(mktemp /tmp/logoutput.XXXX)
email=$(mktemp /tmp/email.XXXX)

# placeholder
lockFile="$HOME/syncCreative.lock"
if [ -f $lockFile ]; then
	echo "Lock file found -- exiting..."
	exit 255
else
	touch $lockFile
	if [ $? -ne 0 ]; then
		echo "can't set lock file... croak."
		exit 255
	fi
fi

# log the start of the operation
startDate="`date +%F\ \a\t\ %T`"
echo "Sync started at $startDate." >> $log

rsync -avzP --delete --exclude='~Archive/*' /Volumes/h$/Creative/ /Volumes/Creative\ Files/Creative/ >> $log 2>&1
rsync -avzP --delete /Volumes/h\$/CreativeClientWork/ /Volumes/Creative\ Files/CreativeClientWork/ >> $log 2>&1

# log end of operation
endDate="`date +%F\ \a\t\ %T`"
echo "Sync ended at $endDate." >> $log

# email results
echo "Creative sync job started $startDate, finished `date +%F\ \a\t\ %T`. Log attached." > $email
uuencode $log synclog.txt >> $email
cat $email | mail -s "Creative Sync Finished" ben.brown@datamark.com

# cleanup
rm -f $log $email $lockFile
exit 0
