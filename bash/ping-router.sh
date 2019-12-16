#!/usr/bin/env bash

if [ -z "${1}" ]; then
    echo "You must supply a hostname or IP to ping, otherwise... how would we function?"
    exit 255
fi

status=1
while [ ${status} -eq 1 ]; do
    echo "$(date) :: Pinging host ${1}..."
    ping -c1 -w1 -q ${1} &> /dev/null
    if [ $? -eq 0 ]; then
        echo "$(date) :: Host ${1} is alive, sending notification!"
        curl -s --form-string "token=acu2n6t3qchjinsjgd9qtx1m5vfha4" --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" --form-string "message=${1} has returned from the dead" https://api.pushover.net/1/messages.json
        status=0
    else
        echo "$(date) :: Host ${1} is still dead. Sleeping."
        sleep 30
    fi
done

exit 0