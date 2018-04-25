#!/bin/sh

# variables
mycnf="/etc/my.cnf"
backupmycnf="/root/backup-my.cnf"
ibb="/usr/local/bin/ibbackup"
mountPoint="/mnt/sydney" # NO TRAILING SLASH!
shortHostName="`echo $HOSTNAME | cut -d \. -f 1`"
tarFileName="ibbackup-`date +%m%d%Y`.tgz"
previousTarFileName="ibbackup-`date +%m%d%Y -d '14 days ago'`.tgz"
includedFiles="$backupmycnf $mycnf $ibb /var/lib/mysql/mysql"
logfile="$HOME/mysql_backup.log"
admin="ben.brown@datamark.com"

# debugging?
if [ "$1" == "debug" ]; then
	debug=1
fi

# functions
function logMessage() {
	if [ -n "$debug" ]; then
		echo $1
	fi

	echo "[`date +%F\ %R`]: " $1 >> $logfile
}

function emailAlert() {
	if [ -n "$debug" ]; then
		logMesage "$1"
	else
		logMessage "$1"
		echo "$1" | mail -s "ibbackup error on `hostname`" $admin
	fi
}

# get destination directory from $backupmycnf
eval `grep '^innodb_data_home_dir' $backupmycnf`
if [ -z "$innodb_data_home_dir" ]; then
	logMessage "Error getting variables from $backupmycnf -- exiting."
	exit 255
else
	if [ ! -d "$innodb_data_home_dir" ]; then
		logMessage "Error -- $innodb_data_home_dir does not exist. Exiting..."
		exit 255
	fi
fi

# this is where we will eventually tar up the FRM files and grant tables
frmAndGrantsTgz="$innodb_data_home_dir/mysqlFiles_`date +%m%d%Y`.tgz"

# make sure $mountPoint exists and is a mount point
if [ -d "$mountPoint" ]; then
	checkMnt=$(mount | grep $mountPoint | awk '{ print $3 }')
	if [ "$checkMnt" != "$mountPoint" ]; then
		emailAlert "$mountPoint is not mounted... exiting."
		exit 255
	fi
else
	emailAlert "$mountPoint does not exist. Create it and mount it to Sydney's SQLBACKUPS share. I can't do anything else till you do..."
fi

# make sure we have ibbackup in the location specified
if [ ! -x $ibb ]; then
	logMessage "Missing ibbackup -- exiting."
	exit 255
fi

# ibbackup does most of the heavy lifting
logMessage "Starting ibbackup..."
$ibb --compress $mycnf $backupmycnf >> $logfile 2>&1
if [ $? -eq 0 ]; then
	logMessage "ibbackup completed successfully."
else
	emailAlert "ibbackup exited with a non-zero status. You'll want to check the log file ($logfile), but here are the last few lines:

`tail -n 20 $logfile`"
	exit 255
fi

# tar up mysql grant tables and FRM files
logMessage "Compressing FRM files and grant tables from /var/lib/mysql..."
cd /var/lib
tar czvf $frmAndGrantsTgz mysql --exclude='ibdata*' --exclude='ib_logfile*' --exclude='*.info' >> $logfile 2>&1
if [ $? -eq 0 ]; then
	logMessage "Done."
else
	emailAlert "Error creating tarball of FRM files and grant tables. The mysql backup process will stop here, you'll need to manually intervene before the next backup cycle to make sure further backups will run."
	exit 255
fi

# dump MySQL table creation data to text, as well
logMessage "Dumping table syntax to SQL file..."
mysqldump -d -A | gzip > "$innodb_data_home_dir/mysqldump-`date +%d%m%Y`.sql.gz" 2>> $logfile
if [ $? -eq 0 ]; then
	logMessage "Done."
else
	errorMsg="Error dumping table syntax to SQL file. I'm going to proceed, but you may want to find out why this happened and run another manual backup."
	logMessage
fi

# compress the contents of the output directory
logMessage "Compressing ibbackup files..."
cd $innodb_data_home_dir
cp -ar $includedFiles .
if [ $? -ne 0 ]; then
	emailAlert "Error copying $mycnf and/or $backupmycnf to tarball -- you'll need to manually copy these to make sure the backup completes."
fi

tar czvf $mountPoint/$shortHostName/$tarFileName * >> $logfile 2>&1
if [ $? -eq 0 ]; then
	logMessage "Compress finished."
	logMessage "Clearing $innodb_data_home_dir..."
	rm -rf $innodb_data_home_dir/*
	if [ $? -eq 0 ]; then
		logMessage "Files deleted."
	else
		emailAlert "Error deleting contents of $innodb_data_home_dir -- please clear this manually."
		exit 255
	fi
else
	emailAlert "Error compressing ibbackup files. Please investigate and clear $innodb_data_home_dir manually."
	exit 255
fi

# cleanup old backup files (we only keep 14 days worth of backups)
if [ -f $mountPoint/$shortHostName/$previousTarFileName ]; then
	logMessage "Cleaning up the backup from `date +%F -d '14 days ago'`..."
	rm -f $mountPoint/$shortHostName/$previousTarFileName
	if [ $? -eq 0 ]; then
		logMessage "Done."
	else
		emailAlert "Error deleting backup file ($previousTarFileName)."
	fi
else
	logMessage "No backup to clean up (looking for $previousTarFileName)"
fi

# done!
logMessage "Backup completed."
exit 0
