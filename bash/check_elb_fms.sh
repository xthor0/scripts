#!/bin/bash

ips="10.99.32.238 10.99.0.99"

while true; do 
  for ip in ${ips}; do
    echo -n "${ip}: "
    STARTTIME=$(date +%s)
    curl --write-out %{http_code} --silent --output /dev/null http://${ip}/api/public/v2/leads/ping
    ENDTIME=$(date +%s)
    ELAPSED=$(expr ${ENDTIME} - ${STARTTIME})
    echo -n " elapsed time: ${ELAPSED}"
    echo
  done
  sleep 1
done
