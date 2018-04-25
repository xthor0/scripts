#!/bin/bash

#backupdir=/home/xthor/m4a_backups

#if [ ! -d ${backupdir} ]; then
#	mkdir ${backupdir}
#fi

cd "/home/xthor/Dropbox/iTunes/iTunes Media"
find Music -iname "*.m4a" | while read i; do
	mp3="${i%m4a}mp3"
	#echo "M4A: $i"
	#echo "MP3: $mp3"
	if [ ! -f "/home/xthor/Dropbox/${i}" ]; then
		echo "Copying ${i} to /home/xthor/Dropbox..."
		cp --parents "${i}" /home/xthor/Dropbox
	fi

	if [ -f "/home/xthor/Dropbox/${mp3}" ]; then
		echo "Matched: ${i}"
		rm -f "/home/xthor/Dropbox/${mp3}"
	else
		echo "Not matched: ${i}"
	fi
	echo "<<=======>>"
done
