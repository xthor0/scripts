#!/bin/bash

#backupdir=/home/xthor/m4a_backups

#if [ ! -d ${backupdir} ]; then
#	mkdir ${backupdir}
#fi

find . -iname "*.m4a" | while read i; do
	if [ -f "${i%m4a}mp3" ]; then
		echo "Skipping ${i}: output file exists"
	else
		echo "Encoding ${i%m4a}mp3"
		ffmpeg -i "$i" -acodec libmp3lame -qscale 255 "${i%m4a}mp3"
		#if [ $? -eq 0 ]; then
		#	rm -f "${i}"
		#fi
	fi
	#echo "debugging"
	#exit 255
done
