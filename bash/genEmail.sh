#!/bin/sh

maxCount=$1
recipient=$2

if [ -z "$maxCount" -o -z "$recipient" ]; then
	echo "Missing arguments..."
	echo "Usage: $0 <number of messages> recipient@blah.com"
	exit 255
fi

# proceed!
errorCount=0
for ((NUM=1; NUM <=$maxCount; NUM++)); do
	echo "sending message $NUM..."
	echo "To: bbrown@itdev.local
From: ben.brown@datamark.com
Subject: Test message $NUM

this is test message $NUM, and here is a bunch of text to go with it
blah!
woo!
" | /usr/sbin/ssmtp $recipient
	
	if [ $? -ne 0 ]; then
		echo "Error sending message $NUM."
		errorCount++
		if [ $errorCount -ge 3 ]; then
			echo "Too many errors ($errorCount). Exiting..."
			exit 255
		fi
	fi
done
