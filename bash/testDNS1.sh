#!/bin/sh
servers="plymouth toquerville calgary vancouver edmonton.datamark.ftp toronto.datamark.ftp aljizah.datamark.ftp suez.datamark.ftp"

date
for server in $servers; do
	echo "Server: $server"
	host -t a ulm.datamark.com. $server | grep 'has address'
	host -t a lb5db-pool.datamark.com. $server | grep 'has address'
	host -t a stingraytools.datamark.com. $server | grep 'has address'
	host -t a www.datamark.com. $server | grep 'has address'
	echo
done
