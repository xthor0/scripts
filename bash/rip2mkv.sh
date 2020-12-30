#!/bin/bash

# create temp file
echo "Scanning disc for title, please wait..."
discinfo=$(mktemp)
makemkvcon --progress=-stdout -r info dev:/dev/sr0 > $discinfo

# get disc title
title=$(cat $discinfo | grep '^DRV:0' | cut -d \, -f 6 | tr -d \")
directory="~/videos/rips/${title}"

# delete temp file
rm -f $discinfo

# if title is not set, exit
if [ -z "$title" ]; then
	echo "Title could not be determined from disc - exiting."
	exit 255
fi

startDate=$(date)
# create directory and start ripping
if [ ! -d "${directory}" ]; then
	mkdir "${directory}"
	if [ $? -ne 0 ]; then
		echo "Error: Could not create directory ${directory}"
		exit 255
	fi
else
	echo "Directory already exists: ${directory} -- exiting!"
	exit 255
fi

pushd "${directory}"

# begin ripping disk
# cribbed this from here: https://gist.github.com/tacofumi/3041eac2f59da7a775c6
# 4800s is too long for TV shows, found out the hard way...
#makemkvcon --progress=-stdout --minlength=4800 -r --decrypt --directio=true mkv dev:/dev/sr0 all .
makemkvcon --progress=-stdout --minlength=600 -r --decrypt --directio=true mkv dev:/dev/sr0 all .
endDate=$(date)

#$HOME/Dropbox/projects/scripts/prowl.pl -apikey=fb18cb558102482e883ac76ba05a3c1b00212e96 -application=MakeMKV -event="MakeMKV rip completed" -notification="Started: $startDate :: Ended: $endDate" -priority=-2
#$HOME/Dropbox/projects/scripts/nma.sh MakeMKV "MakeMKV rip completed" "Started: $startDate :: Ended: $endDate" -2

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=MakeMKV rip of ${title} completed <> Started: $startDate :: Ended: $endDate" \
  https://api.pushover.net/1/messages.json

popd

exit 0
