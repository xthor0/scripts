#!/bin/bash

# we need to get the IP address of vboxnet0
vbox_ip=$(ip a sh dev vboxnet0 | grep inet\ | awk '{ print $2 }' | cut -d \/ -f 1)

# default network device
default_dev=$(ip route | grep ^default | awk '{ print $5 }')

# Flush tables
iptables -F		# flush chains (combines next to)
iptables -X		# delete user chains
iptables -Z		# zero counters

##Disconnects all current sessions when executed.
for t in `cat /proc/net/ip_tables_names`; do
        iptables -F -t $t
        iptables -X -t $t
        iptables -Z -t $t
done

# NAT VM network to internet
iptables -t nat -A POSTROUTING -o $default_dev -j MASQUERADE

# Everything should be loaded, start forwarding
echo "1" > /proc/sys/net/ipv4/ip_forward

# dnsmasq
# TODO: Make dynamic based on info we get from ip output
dnsmasq -k -d --interface=vboxnet0 --dhcp-option=3,10.188.55.1 --dhcp-range=10.188.55.10,10.188.55.250,1h --dhcp-leasefile=/tmp/dnsmasq-vbox.leases --log-queries --local-service

# this runs in foreground right now...
