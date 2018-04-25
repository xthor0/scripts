#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Find out if a host is being monitored in Nagios."
	echo "Usage:

`basename $0` -F <path/to/file> [ -d ]

	the file referenced should be a text file with one line per host being monitored by Nagios."
	exit 255
}

# get command-line args
while getopts "F:d" OPTION; do
	case $OPTION in
		F) input_file="$OPTARG";;
		d) debug=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$input_file" ]; then
	usage
fi

### BEGIN
# read input file
count=0
echo "host,dns servers,a record"
cat "$input_file" | grep -v datamark.com | while read host; do
	echo -n "$host,"
	# get name servers
	if [ `echo $host | grep -o '\.' | tr -d \\\n | wc -c` -ge 2 ]; then
		# $host is a subdomain -- we need to get the base domain
		base_domain="`echo $host | awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//'`"
		dns_servers="`dig -t ns $base_domain @8.8.8.8 | grep -A 5 ';; ANSWER SECTION:' | grep -v '^;;' | awk '{ print $5 }' | tr \\\n ' '`"
	else
		dns_servers="`dig -t ns $host @8.8.8.8 | grep -A 5 ';; ANSWER SECTION:' | grep -v '^;;' | awk '{ print $5 }' | tr \\\n ' '`"
	fi
	echo -n "$dns_servers,"

	# A record check
	a_record="`dig -t a $host @8.8.8.8 | grep -A 1 ';; ANSWER SECTION:' | grep -v '^;;' | awk '{ print $5 }'`"
	echo "$a_record"
done

exit 0
