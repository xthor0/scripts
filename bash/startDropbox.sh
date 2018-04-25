#!/bin/bash

dboxs=$HOME/bin/dropbox.py
if [ -x $dboxs ]; then
	$dboxs running
	if [ $? -ne 1 ]; then
		$dboxs start
		
		# wait 30 seconds - and then see if Dropbox is running
		sleep 30
		
		$dboxs running
		if [ $? -ne 1 ]; then
			# send message to Pushover - dropbox won't start
			curl -s \
			  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
			  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
			  --form-string "message=$(date) :: Dropbox is having issues starting on $HOSTNAME - please investigate." https://api.pushover.net/1/messages.json
		fi
	fi
fi

exit 0
