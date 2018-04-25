#!/bin/sh

# logs
log=$(mktemp /tmp/logoutput.XXXX)
email=$(mktemp /tmp/email.XXXX)

# source/target variables
source="/Volumes/Creative Files"
target="/Volumes/Taipei_Backups"

# email address of admins
admin="sysadmins@datamark.com"

# the lock file prevents this script from running twice
lockFile="$HOME/backup${HOSTNAME}.lock"
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

# verify that target is mounted
mountStatus="`/sbin/mount | grep $target | awk '{print $3}'`"
if [ "$mountStatus" != "$target" ]; then
	echo "$target is not mounted -- backup cannot proceed."
	exit 255
fi

# log the start of the operation
startDate="`date +%F\ \a\t\ %T`"
echo "Backup started at $startDate." >> $log

#rsync -avE --modify-window=1 --delete "${source}/" "${target}/${targetDir}/" >> $log 2>&1
ditto -v --norsrc "${source}" "${target}/${source}/" >> $log 2>&1

# log end of operation
endDate="`date +%F\ \a\t\ %T`"
echo "Sync ended at $endDate." >> $log

# email results
echo "$HOSTNAME backup started $startDate, finished `date +%F\ \a\t\ %T`. Backup log attached." > $email
uuencode $log synclog.txt >> $email
cat $email | mail -s "$HOSTNAME Backup Log" $admin

# cleanup
rm -f $log $email $lockFile
exit 0
