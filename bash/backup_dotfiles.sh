#!/bin/bash
output="$(whoami)_$(date +%Y%m%d).tgz"
user=$(whoami)

tar --exclude=Dropbox --exclude='.dropbox*' --exclude='VirtualBox*' --exclude=downloads --exclude=Downloads --exclude=kickstart -czf "/tmp/$output" /home/$user

if [ $? -eq 0 ]; then
	mv /tmp/$output /home/$user/Dropbox/Backup
fi

exit 0
