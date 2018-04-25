#!/bin/sh

base="/home/bbrown/qadns"
for env in qa qa2; do 
	rsync -avz --delete root@${env}dns.datamark.com:/var/named/chroot/etc/ ${base}/${env}/etc/ && 	rsync -avz --delete root@${env}dns.datamark.com:/var/named/chroot/var/ ${base}/${env}/var/ && $HOME/projects/scripts/bind2dnsmasq.php --env=$env
done

exit 0
