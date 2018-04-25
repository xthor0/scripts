#!/bin/bash

if [ -z "$1" ]; then
	echo "usage: $0 [message]"
	echo
	exit 255
fi

curl -s --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" --form-string "message=$*" https://api.pushover.net/1/messages.json >& /dev/null
retval=$?
echo

if [ $retval -eq 0 ]; then
	echo "Message sent to Pushover."
else
	echo "Error sending message to Pushover."
fi

exit 0
