#!/bin/bash

backupdir=/storage/xthor/m4a_mp3

find . -iname "*.m4a" | while read i; do
	mp3="${i%m4a}mp3"
	if [ -f "${mp3}" ]; then
		echo "Processing: ${i}..."
		cp --parents "${mp3}" $backupdir
		if [ -f ${backupdir}/"${mp3}" ]; then
			rm -f "${mp3}"
		fi
	fi
done
