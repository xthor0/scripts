#!/bin/bash

# run this command to get a nicely formatted list of ports that each service is using
# mostly for use to paste into nmap -Pn <paste> <ip or ips>
docker service ls | awk '{ print $6 }' | grep '^\*' | cut -d \- -f 1 | cut -d \: -f 2 | sort | tr \\n , | sed 's/,$/\n/g'

# also helpful - a list of IP addresses of each node
# sometimes nodes return 0.0.0.0 - strange
for NODE in $(docker node ls --format '{{.Hostname}}'); do echo -e "${NODE} - $(docker node inspect --format '{{.Status.Addr}}' "${NODE}")"; done
