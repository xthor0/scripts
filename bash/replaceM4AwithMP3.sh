#!/bin/bash

sourcedir=/storage/xthor/m4a_mp3
backupdir=/storage/xthor/m4a_backups

find . -iname "*.m4a" | while read i; do
	mp3="${sourcedir}/${i%m4a}mp3"
	if [ -f "${mp3}" ]; then
		echo "Found: ${mp3}..."
		cp --parents "${mp3}" $backupdir
		if [ -f "${mp3}" ]; then
			rm -f "${i}"
		fi
	fi
done
