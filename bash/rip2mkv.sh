#!/bin/bash

function cleanup_exit() {
	rm -f ${discinfo}
	exit 0
}

# create temp file
echo "Scanning disc for title, please wait..."
discinfo=$(mktemp)
makemkvcon --progress=-stdout -r info dev:/dev/sr0 > $discinfo

# get disc title
title=$(cat $discinfo | grep '^DRV:0' | cut -d \, -f 6 | tr -d \")
directory="/storage/videos/rips/${title}"

# if title is not set, exit
if [ -z "$title" ]; then
	echo "Title could not be determined from disc - exiting."
	cleanup_exit
fi

startDate=$(date)
# create directory and start ripping
if [ ! -d "${directory}" ]; then
	mkdir "${directory}"
	if [ $? -ne 0 ]; then
		echo "Error: Could not create directory ${directory}"
		cleanup_exit
	fi
else
	echo "Directory already exists: ${directory} -- exiting!"
	cleanup_exit
fi

pushd "${directory}"

# save the discinfo file and then delete it (for debugging purposes)
discinfo_backup="${HOME}/discinfo/${title}.txt"
if [ -f "${discinfo_backup}" ]; then
	discinfo_backup="${HOME}/discinfo/${title}-2.txt"
	if [ -f "${discinfo_backup}" ]; then
		echo "WTF, how many of this disc have you ripped?? I can't back up this discinfo."
	fi
fi

cp ${discinfo} "${discinfo_backup}"

# begin ripping disk
# cribbed this from here: https://gist.github.com/tacofumi/3041eac2f59da7a775c6
makemkvcon --progress=-stdout --minlength=600 -r --decrypt --directio=true mkv dev:/dev/sr0 all .
endDate=$(date)

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token=a74zm3s7dc577532z2qet8fpkwuy6f" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=MakeMKV rip of ${title} completed <> Started: $startDate :: Ended: $endDate" \
  https://api.pushover.net/1/messages.json

popd

cleanup_exit
