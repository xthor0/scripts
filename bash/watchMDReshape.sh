#!/bin/bash

while [ $(grep reshape /proc/mdstat | wc -l) -eq 1 ]; do
	echo "Still reshaping at $(date)..."
	sleep 10
done

# pushover notification
curl -s \
  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Restripe on $HOSTNAME completed - don't forget to grow the filesystem" \
  https://api.pushover.net/1/messages.json

exit 0 
