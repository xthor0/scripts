#!/bin/bash

IPTABLES=/sbin/iptables

# get command-line args
while getopts "d:" OPTION; do
	case $OPTION in
		d) WAN_DEV=${OPTARG};;
		*) usage;;
	esac
done

if [ -z "${WAN_DEV}" ]; then
  echo "Usage: $0 -d <network_interface>"
  exit 255
fi

${IPTABLES} -t nat -A POSTROUTING -o ${WAN_DEV} -j MASQUERADE

echo "1" > /proc/sys/net/ipv4/ip_forward

exit 0
