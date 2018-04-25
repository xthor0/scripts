#!/bin/bash

IPTABLES=/sbin/iptables
WAN_DEV=eno1

${IPTABLES} -t nat -A POSTROUTING -o ${WAN_DEV} -j MASQUERADE

echo "1" > /proc/sys/net/ipv4/ip_forward

