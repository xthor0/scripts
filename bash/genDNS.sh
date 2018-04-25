#!/bin/bash

datamarkinc_iplist="10.0.0.14,10.0.0.16,10.1.1.25,10.1.1.26"
datamarkftp_iplist="10.5.0.25,10.5.0.26,10.5.0.67,10.5.0.75,10.2.1.25,10.2.1.26,10.2.1.27,10.2.1.28"
#datamarkftp_iplist="10.5.0.25,10.5.0.26,10.2.1.25,10.2.1.26"

datamarkinc_zones="datamark.com datamark-inc.com 0.0.10.in-addr.arpa 1.0.10.in-addr.arpa 2.0.10.in-addr.arpa 3.0.10.in-addr.arpa \
		0.16.172.in-addr.arpa 1.31.172.in-addr.arpa 125.168.192.in-addr.arpa"
datamarkftp_zones="datamark.ftp 0.5.10.in-addr.arpa 1.2.10.in-addr.arpa 2.2.10.in-addr.arpa"

datamarkinc_servers="westpoint101.datamark-inc.com westpoint102.datamark-inc.com westpoint201.datamark-inc.com westpoint203.datamark-inc.com"
datamarkftp_servers="annapolis101.datamark.ftp annapolis102.datamark.ftp annapolis201.datamark.ftp annapolis202.datamark.ftp"

### Reset secondaries and allow zone transfers from datamark-inc.com to datamark.ftp servers
function num1() {
for server in $datamarkinc_servers; do
	for zone in $datamarkinc_zones; do
		echo "dnscmd $server /zoneresetsecondaries $zone /securelist $datamarkftp_iplist /notifylist $datamarkftp_iplist"
	done
	echo
done
}

function num2() {
for server in $datamarkftp_servers; do
	for zone in $datamarkftp_zones; do
		echo "dnscmd $server /zoneresetsecondaries $zone /securelist $datamarkinc_iplist /notifylist $datamarkinc_iplist"
	done
	echo
done
}

function num3() {
for server in $datamarkftp_servers; do
	for zone in $datamarkinc_zones; do
		echo "dnscmd $server /zoneadd $zone /secondary $datamarkinc_iplist /file $zone"
	done
	echo
done
}


num1
exit 0
