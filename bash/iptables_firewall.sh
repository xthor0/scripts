#!/bin/bash
#
# $Source: /cvsroot/devil-linux/build/config/etc/init.d/firewall.rules.2nic,v $
# $Revision: 1.17 $
# $Date: 2009/06/10 01:07:49 $
#
# http://www.devil-linux.org
#
#
# Basic Firewall rules for 2 NIC's and NAT
#
###############################################################################
# *WARNING*  *WARNING*  *WARNING*  *WARNING*  *WARNING*  *WARNING*  *WARNING* #
#									      #
#		     MODIFY THIS FILE AT YOUR OWN RISK!!!		      #
#									      #
#  Only modify this file if you fully understand firewalling and netfilter!   #
#  Mistakes can result in loss of security and/or other networking problems.  #
#									      #
#  Recommend reading to learn netfilter include (but are not limited to):     #
#									      #
#   http://www.knowplace.org/netfilter/syntax.html			      #
#   http://iptables-tutorial.frozentux.net/chunkyhtml/index.html	      #
#   http://www.netfilter.org/documentation/index.html#documentation-tutorials #
#									      #
# *WARNING*  *WARNING*  *WARNING*  *WARNING*  *WARNING*  *WARNING*  *WARNING* #
###############################################################################

# Path to executables
IPTABLES=/sbin/iptables
MODPROBE=/sbin/modprobe

OUT_DEV=ppp0	# Internet
INT_DEV=eth1	# Internal/protected network.

BEDEVERE=10.200.99.35
BLACKKNIGHT=10.200.99.30

# Stop forwarding while setting up.
echo "0" > /proc/sys/net/ipv4/ip_forward 

# Uncomment the following line to enable logging:
# LOGGING="yes"

# Optional Modules:
${MODPROBE} ip_conntrack_ftp
${MODPROBE} ip_nat_ftp
${MODPROBE} ip_conntrack_irc
${MODPROBE} ip_nat_irc
#${MODPROBE} ip_owner
${MODPROBE} ipt_state

# Only needed if we're going to log.
[ -n "$LOGGING" ] && ${MODPROBE} ipt_LOG

# Flush tables & setup Policy
${IPTABLES} -F  # flush chains
${IPTABLES} -X  # delete user chains
${IPTABLES} -Z	# zero counters
for t in `cat /proc/net/ip_tables_names`
do
	${IPTABLES} -F -t $t
	${IPTABLES} -X -t $t
	${IPTABLES} -Z -t $t
done

### BEGIN IPTABLES rules ###

${IPTABLES} -P INPUT DROP	# Policy = DROP
${IPTABLES} -P OUTPUT DROP	#  Drop all packets that are
${IPTABLES} -P FORWARD DROP	#  not specifically accepted.

# make interactive sesions a bit more interactive under load
${IPTABLES} -t mangle -N SETTOS
${IPTABLES} -A SETTOS -t mangle -p TCP --sport ssh -j TOS --set-tos Minimize-Delay
${IPTABLES} -A SETTOS -t mangle -p TCP --sport ftp -j TOS --set-tos Minimize-Delay
${IPTABLES} -A SETTOS -t mangle -p TCP --sport ftp-data -j TOS --set-tos Maximize-Throughput

# Local interface - do not delete!
${IPTABLES} -A INPUT -i lo -j ACCEPT
${IPTABLES} -A OUTPUT -o lo -j ACCEPT

# We accept anything from the inside.
${IPTABLES} -A INPUT -i ${INT_DEV} -j ACCEPT
${IPTABLES} -A OUTPUT -o ${INT_DEV} -j ACCEPT

# Allow our firewall to connect.
${IPTABLES} -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${IPTABLES} -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Allow Ping and friends.
${IPTABLES} -A INPUT  -p icmp -j ACCEPT
${IPTABLES} -A OUTPUT -p icmp -j ACCEPT

# SSH to firewall
${IPTABLES} -A INPUT -p tcp --dport 22 -i ${OUT_DEV} -j ACCEPT

# Fast reject for Ident to eliminate email delays.
${IPTABLES} -A INPUT -p TCP --dport 113 -i ${OUT_DEV} -j REJECT --reject-with tcp-reset

### Port forwarding examples
# Allow SSH from outside the firewall to Blackknight
#${IPTABLES} -A PREROUTING -i ${OUT_DEV} -t nat -p TCP --dport 22 -j DNAT --to ${SERVER_IP}
#${IPTABLES} -A FORWARD -p TCP -d ${BLACKKNIGHT} --dport 22 -i ${OUT_DEV} -o ${INT_DEV} -j ACCEPT

${IPTABLES} -t mangle -A PREROUTING -j SETTOS

# Masquerading for everyone (aka NAT, PAT, ...)
${IPTABLES} -t nat -A POSTROUTING -o ${OUT_DEV} -j MASQUERADE

# Block invalid connections from the internet.
[ -n "$LOGGING" ] && \
  ${IPTABLES} -A FORWARD -m state --state NEW,INVALID -i ${OUT_DEV} -j LOG --log-prefix "FORWARD INVALID: "
${IPTABLES} -A FORWARD -m state --state NEW,INVALID -i ${OUT_DEV} -j DROP

# Allow connections to the internet from the internal network.
${IPTABLES} -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
${IPTABLES} -A FORWARD -m state --state NEW -i ${INT_DEV} -j ACCEPT

# Prevent NetBIOS and Samba from leaking.
${IPTABLES} -A FORWARD -p TCP -m multiport --dports 135,137:139,445 -j DROP
${IPTABLES} -A FORWARD -p UDP -m multiport --dports 135,137:139,445 -j DROP

# Log invalid packets from DROP policy:
if [ -n "$LOGGING" ] ; then
    ${IPTABLES} -A INPUT -d 255.255.255.255 -j DROP # do not log broadcasts
    ${IPTABLES} -A INPUT -d 224.0.0.0/8 -j DROP # do not log Microsoft multicasts
    ${IPTABLES} -A INPUT -m limit --limit 3/minute --limit-burst 3 -j LOG --log-prefix "INPUT policy: "
    ${IPTABLES} -A OUTPUT -m limit --limit 3/minute --limit-burst 3 -j LOG --log-prefix "OUTPUT policy: "
    ${IPTABLES} -A FORWARD -m limit --limit 3/minute --limit-burst 3 -j LOG --log-prefix "FORWARD policy: "
fi

### END IPTABLES rules ###

# enable dynamic IP address following
echo 2 > /proc/sys/net/ipv4/ip_dynaddr

# stop some smurf attacks.
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Don't accept source routed packets.
echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route

# Syncookies
echo "1" > /proc/sys/net/ipv4/tcp_syncookies

# Stop IP spoofing,
for interface in /proc/sys/net/ipv4/conf/*/rp_filter; do
	echo "1" > $interface
done

# Stop ICMP redirect
for interface in /proc/sys/net/ipv4/conf/*/accept_redirects; do
	echo "0" > ${interface}
done

# Enable bad error message protection.
echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Enabling IP forwarding.
echo "1" > /proc/sys/net/ipv4/ip_forward

# END
exit 0
