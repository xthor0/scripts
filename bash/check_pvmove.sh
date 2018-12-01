#!/bin/bash

while true; do
        ps aux | grep -v grep | grep -q pvmove
        if [ $? -eq 0 ]; then
                echo "pvmove still running - sleeping 60 seconds."
                sleep 60
        fi
done

message="pvmove on $HOSTNAME completed!"

# send pushover notification
curl -s \
  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Notification: ${message}" \
https://api.pushover.net/1/messages.json

exit 0
