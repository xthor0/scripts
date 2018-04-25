#!/bin/sh

if [ -z "$*" ]; then
	echo "This script expects a list of domains as an argument."
	exit 255
fi

for domain in $*; do
	# convert it all to lowercase
	domain="`echo $domain | tr [:upper:] [:lower:]`"

	# get tld
	tld="`echo $domain | cut -d \. -f 2`"

	# .org and .info domains look different in a whois
	if [ "$tld" == "org" -o "$tld" == "info" ]; then
		expirationdate="`whois $domain | grep 'Expiration' | cut -d \: -f 2 | cut -d ' ' -f 1`"
	else
		expirationdate="`whois $domain | grep 'Expiration' | cut -d \: -f 2`"
	fi

	# convert dates to Unix time for easier math
	todayUnixTime=`date +%s`
	domainUnixTime=`date +%s -d $expirationdate`
	twoWeeksInSeconds=1209600

	# if the domain will expire in two weeks, we put a * next to it
	timeDiff=`expr $domainUnixTime - $todayUnixTime`
	if [ $timeDiff -le $twoWeeksInSeconds ]; then
		alert="<EXPIRES"
		domainstoremove="$domainstoremove $domain"
	else
		alert=""
	fi

	# spit it out
	printf "%-40s: %s %s\n" $domain $expirationdate $alert
done

# print out a list of domains to run through nagiosmgr
if [ -n "$domainstoremove" ]; then
	echo
	echo "Domains to remove from Nagios:"
	echo $domainstoremove
fi

exit 0
