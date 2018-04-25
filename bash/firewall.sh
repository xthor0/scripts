#!/bin/bash
#
# Firewall rules - xthorsworld
# stolen shamelessly from Devil Linux :)

#############################################################################
## DECLARE VARIABLES ########################################################

# Path to executables
IPTABLES=/sbin/iptables
MODPROBE=/sbin/modprobe

# Interface aliases
LPB_DEV=lo	# Loopback interface
LAN_DEV=eth1.3	# Router/FW LAN interface
KID_DEV=eth1.2  # used for kids access to interwebz
WAN_DEV=p2p1	# Router/FW WAN interface

## END VARIABLE DECLARATIONS ################################################
#############################################################################

#############################################################################
## PRELIMINARY SETUP ########################################################

# Stop forwarding while ruleset is loading (paranoia)
echo "0" > /proc/sys/net/ipv4/ip_forward

# Optional modules:
#${MODPROBE} ip_conntrack_ftp
#${MODPROBE} ip_conntrack_irc
#${MODPROBE} ip_nat_ftp
#${MODPROBE} ip_nat_irc

# Flush tables
${IPTABLES} -F		# flush chains (combines next to)
${IPTABLES} -X		# delete user chains
${IPTABLES} -Z		# zero counters

##Disconnects all current sessions when executed.
for t in `cat /proc/net/ip_tables_names`; do
        ${IPTABLES} -F -t $t
        ${IPTABLES} -X -t $t
        ${IPTABLES} -Z -t $t
done

# Set up default policies
${IPTABLES} -P INPUT DROP	# INPUT:   connections directly to firewall
${IPTABLES} -P OUTPUT ACCEPT	# OUTPUT:  connections out from firewall
${IPTABLES} -P FORWARD DROP	# FORWARD: traffic forwarding across interfaces

# Previously initiated and accepted exchanges bypass rule checking
# (Statefullness!)
${IPTABLES} -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${IPTABLES} -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${IPTABLES} -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Loopback interfaces shouldn't be filtered
${IPTABLES} -A INPUT -i ${LPB_DEV} -j ACCEPT
${IPTABLES} -A OUTPUT -o ${LPB_DEV} -j ACCEPT


# allow access to firewall from LAN
${IPTABLES} -A INPUT -i ${LAN_DEV} -j ACCEPT
${IPTABLES} -A INPUT -i ${KID_DEV} -j ACCEPT
${IPTABLES} -A FORWARD -i ${LAN_DEV} -j ACCEPT

# block access to the internet during certain time periods on $KID_DEV
${IPTABLES} -A FORWARD -i ${KID_DEV} -o ${WAN_DEV} -m time --timestart 00:00:00 --timestop 07:00:00 --weekdays Mon,Tues,Wed,Thur,Fri,Sat,Sun -j DROP
${IPTABLES} -A FORWARD -i ${KID_DEV} -o ${WAN_DEV} -m time --timestart 20:00:00 --timestop 23:59:59 --weekdays Sun,Mon,Tues,Wed,Thur -j DROP
${IPTABLES} -A FORWARD -i ${KID_DEV} -o ${WAN_DEV} -m time --timestart 21:00:00 --timestop 23:59:59 --weekdays Fri,Sat -j DROP
${IPTABLES} -A FORWARD -i ${KID_DEV} -j ACCEPT

#NAT Rules
${IPTABLES} -t nat -A PREROUTING -i ${WAN_DEV} -p tcp --dport 2222 -j DNAT --to-destination 10.200.99.11:22
${IPTABLES} -A FORWARD -d 10.200.99.11 -p tcp --dport 22 -m state --state NEW -j ACCEPT
#${IPTABLES} -t nat -A PREROUTING -i ${WAN_DEV} -p tcp --dport 2223 -j DNAT --to-destination 10.200.99.12:22
#${IPTABLES} -A FORWARD -d 10.200.99.12 -p tcp --dport 22 -m state --state NEW -j ACCEPT

#Outbound NAT
#${IPTABLES} -t nat -A POSTROUTING -s 192.168.201.50 -o ${WAN_DEV} -j SNAT --to 66.133.110.170
${IPTABLES} -t nat -A POSTROUTING -o ${WAN_DEV} -j MASQUERADE


#############################################################################
## ENABLE IP STACK PROTECTION IN KERNEL: ####################################
# Stop some smurf attacks
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Don't accept source routed packets
echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route

# Syn cookies (see http://cr.yp.to/syncookies.html)
echo "1" > /proc/sys/net/ipv4/tcp_syncookies

# Stop ICMP redirect
for interface in /proc/sys/net/ipv4/conf/*/accept_redirects; do
        echo "0" > ${interface}
done

# Enable bad error message protection
echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

## END IP STACK PROTECTION ##################################################
#############################################################################

# Everything should be loaded, start forwarding
echo "1" > /proc/sys/net/ipv4/ip_forward

exit 0
