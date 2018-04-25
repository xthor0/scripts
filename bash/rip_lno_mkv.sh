#!/bin/bash

startDate=$(date)
# begin ripping disk
makemkvcon --progress=-stdout mkv dev:/dev/sr0 all .
endDate=$(date)

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=MakeMKV rip completed <> Started: $startDate :: Ended: $endDate" \
  https://api.pushover.net/1/messages.json

exit 0
