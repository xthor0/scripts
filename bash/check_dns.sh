#!/bin/bash

DNS_SERVERS_CORP="westpoint101 westpoint102 westpoint201 westpoint203"
DNS_SERVERS_DMZ="annapolis101 annapolis102 annapolis201 annapolis202"
DNS_SERVERS=""
FORMAT="%15s: %s"

if [ -z "$1" ]; then
	echo "Please provide the hostname you wish to look up in DNS as the first arg to this script."
	exit 255
fi

for server in ${DNS_SERVERS_CORP}; do
	DNS_SERVERS="${DNS_SERVERS} ${server}.datamark-inc.com"
done

for server in ${DNS_SERVERS_DMZ}; do
	DNS_SERVERS="${DNS_SERVERS} ${server}.datamark.ftp"
done

for server in ${DNS_SERVERS}; do
	RESULT="`dig @${server} ${1} | grep -A1 ';; ANSWER SECTION:' | awk '{ print $5 }'`"
	printf "%-40s: %s\n" $server $RESULT
done

exit 0
