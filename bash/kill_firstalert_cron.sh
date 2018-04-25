#!/bin/sh

# variables
cron_user="www-data"
sudo_password="Hu3v05C@m313r05"
datestring="`date +%m%d%Y`"
admin="ben.brown@datamark.com"

# do it to it
## back up crontab
echo $sudo_password | sudo -S crontab -u ${cron_user} -l > $HOME/crontab-${cron_user}-${datestring}
if [ $? -ne 0 ]; then
	echo "Error backing up ${cron_user}'s crontab." | mail -s "Crontab Backup Failed on $HOSTNAME" $admin
	exit 255
fi

## remove crontab
echo $sudo_password | sudo -S crontab -u ${cron_user} -r
if [ $? -ne 0 ]; then
	echo "Error removing ${cron_user}'s crontab." | mail -s "Crontab Removal Failed on $HOSTNAME" $admin
	exit 255
else
	echo "Crontab has been removed on $HOSTNAME and backed up to $HOME/crontab-${cron_user}-${datestring}. Restore this crontab when $HOSTNAME lives again." | mail -s "Crontab on $HOSTNAME" $admin
fi

exit 0
