#!/bin/bash

# just a crappy script I cobbled together because I was sick of doing it manually

# these are all the Docker hosts
IPLIST="10.15.1.65 10.15.49.43 10.15.27.134 10.15.27.131 10.15.49.42 10.15.27.132 10.15.1.62"

# I know Leads runs on port 3000
# I also know the health check URL
URI="api/public/v2/leads/ping"

# I want to loop through these suckers, sleep 1 second, and see if I ever get anything other than
# HTTP 200
echo "Checking URI: ${URI}"
while true; do
        date
        for ip in $IPLIST; do
          echo -n "${ip}: "
          curl --write-out %{http_code} --silent --output /dev/null http://${ip}:3000/${URI}
          echo
        done
  sleep 1
done

exit
