#!/bin/bash

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token=a6ivpugd59ur6byp4jy1djiban5h3m" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Notification: $*" \
https://api.pushover.net/1/messages.json
