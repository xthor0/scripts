#!/bin/bash

qaenv="qa2"
path="/etc/httpd/sites-available"

echo "Processing vhost files in ${path} for ${qaenv}..."

while read file; do
	# parse the file for ServerName and ServerAlias information
	servername=$(grep ^ServerName "${file}" | awk '{ print $2 }')
	serveralias=$(grep ^ServerAlias "${file}" | awk '{ print $2 }')

	# check to make sure we got data
	if [ -z "${servername}" ]; then
		echo -n "!"
		badfiles="${badfiles} ${file}"
		continue
	fi

	# has this already been run?
	echo ${servername} | grep ${qaenv}.datamark.com >& /dev/null
	if [ $? -eq 0 ]; then
		echo -n "+"
		okfiles="${okfiles} ${file}"
		continue
	fi

	# escape any asterisks in serveralias variable
	echo ${serveralias} | grep \* >& /dev/null
	if [ $? -eq 0 ]; then
		wildcard=1
	fi

	# replace the old data with the new data
	sed -i "s/^ServerName.*/ServerName ${servername}.${qaenv}.datamark.com/g" "${file}"
	
	if [ -n "${serveralias}" ]; then
		if [ -n "${wildcard}" ]; then
			sed -i 's/^ServerAlias.*/ServerAlias \*.'"${servername}.${qaenv}.datamark.com"'/g' "${file}"
		else
			sed -i "s/^ServerAlias.*${serveralias}/ServerAlias www.${servername}.${qaenv}.datamark.com/g" "${file}"
		fi
	fi

	# output status
	echo -n "."
done < <(find "${path}" -type f -print)

echo

if [ -n "${badfiles}" ]; then
	echo "Unable to process the following files: "
	echo "${badfiles}"
fi

if [ -x /etc/init.d/httpd ]; then
	echo "Restarting HTTPD..."
	sudo /sbin/service httpd restart
fi

exit 0
