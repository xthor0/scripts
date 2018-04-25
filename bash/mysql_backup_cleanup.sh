#!/bin/bash

# this script has a simple job: Compress all files in /storage/<hostname> as /storage/<hostname>/archive/date.tar
# runs every Saturday at 10 AM

dir=/storage
date="$(date +%Y%m%d)"

find /storage -maxdepth 1 -type d | while read subdir; do
	if [ "$subdir" == "/storage" ]; then
		continue
	fi

	if [ -d "${subdir}/full" ]; then
		pushd ${subdir}
		if [ ! -d archive ]; then
			mkdir archive
		fi
		tar cf archive/$(date +%Y%m%d).tar full *_incremental
		if [ $? -eq 0 ]; then
			#rm -rf full *_incremental
			mv full ${date}_full
			for i in *_incremental; do
				mv "$i" "${date}_${i}"
			done
		fi
		popd
	fi
done

exit 0
