#!/bin/bash

### script overview
# 1. figure out what day of the week it is
# 2. is it Sunday? Then we need a full backup
# 3. Any other day? Does a full backup exist? create it - otherwise create an incremental backup

#### Variables
admin=bbrown@helixeducation.com
baseDir=/mnt/mysqlbackup
fullDir="${baseDir}/full"
day="$(date +%a)"
incDir="${baseDir}/${day}_incremental"
fullBackupCMD="/usr/bin/innobackupex --no-timestamp --compress --compress-threads=4 --galera-info --safe-slave-backup ${fullDir}"
incBackupCMD="/usr/bin/innobackupex --compress --no-timestamp --compress-threads=4 --galera-info --safe-slave-backup --incremental --incremental-basedir=${fullDir} ${incDir}"

# logging
log=$(mktemp)

#### PREFLIGHT CHECKS
# do we have the innobackupex binary?
if [ ! -x /usr/bin/innobackupex ]; then
	echo "Missing innobackupex binary -- exiting."
	exit 255
fi

# is /mnt/mysqlbackup mounted?
mountpoint -q ${baseDir}
if [ $? -eq 1 ]; then
	echo "$baseDir is not mounted - exiting."
	exit 255
fi

#### BEGIN
# Sunday is full backup day. Unless, of course, a full backup doesn't exist - then we create one anyhow
if [ "$day" == "Sun" ]; then
	if [ -d "${fullDir}" ]; then
		echo "Error: a full backup should not exist on a Sunday! The backup script is NOT properly packaging the backup files on $HOSTNAME" | mail -s "innobackupex error" $admin
		exit 255
	else
		$fullBackupCMD >& $log
	fi
else
	if [ -d "${incDir}" ]; then
		echo "Error: Incremental dir already exists on $HOSTNAME - the backup script is NOT properly packaging the backup files" | mail -s "innobackupex error" $admin
		exit 255
	else
		if [ -d "${fullDir}" ]; then
			$incBackupCMD >& $log
		else
			$fullBackupCMD >& $log
		fi
	fi
fi

# make sure the backup completed successfully
if [ $(grep "innobackupex: completed OK" $log | wc -l) -ne 1 ]; then
	email=$(mktemp)
	echo "Error: innobackupex does not show a successful exit. Below are the contents of the log file." > $email
	echo "=================" >> $email
	cat $log >> $email
	cat $email | mail -s "innobackupex error on $HOSTNAME" $admin
	rm -f $log $email
	exit 255
fi

# end
rm -f $log
exit 0
