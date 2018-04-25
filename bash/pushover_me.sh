#!/bin/bash

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Notification: $*" \
https://api.pushover.net/1/messages.json
