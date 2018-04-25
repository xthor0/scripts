#!/bin/sh

webPool="10.2.1.200"
nagiosWeb="amsterdam.datamark.com"
publicWebPoolIP="66.133.120.242"
failoverWebPoolIP="206.173.159.200"

# display usage
function usage() {
	echo "`basename $0`: Check to see if a domain has been sunsetted, or if it exists in Nagios"
	echo "Usage:

`basename $0` -u <list of domains in domain1:domain2:domain3 format, no spaces>"
	exit 255
}

# get command-line args
while getopts "V:u:l:" OPTION; do
	case $OPTION in
		u) url="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$url" ]; then
	usage
fi

# simple test - we grab the title string and if it says "<title>Site or Page Not Available!</title>" we know it's sunsetted
sunset_title="<title>Site or Page Not Available!</title>"
dead_title="<title>phpinfo()</title>"

for domain in `echo $url | tr \: ' '`; do
	# did this get passed in with www?
	if [ `echo $domain | grep '^www' | wc -l` -eq 1 ]; then
		domain=`echo $domain | cut -b 5-`
	fi

	compared_site=`echo "GET / HTTP/1.0
host: $domain
" | nc $webPool 80 | grep '<title>.*</title>'`
	
	echo -n "$domain: "
	# is it even pointed at us?
	currentIP="`host $domain. | grep 'has address' | awk '{ print $4 }'`"
	if [ "$currentIP" == "$webPool" -o "$currentIP" == "$publicWebPoolIP" -o "$currentIP" == "$failoverWebPoolIP" ]; then
		echo -n "Pointed at us, "
	else
		echo -n "NOT pointed at us, "
	fi

	# check for sunset string
	if [ "$compared_site" == "$sunset_title" ]; then
		echo -n "Sunsetted"
	elif [ "$compared_site" == "$dead_title" ]; then
		echo -n "Dead"
	else
		echo -n "Live"
	fi

	# check it in Nagios
	ssh $nagiosWeb "
		if [ \`grep -i $domain /etc/nagios/vhosts.d/* | wc -l\` -eq 0 ]; then
			echo \", not in Nagios\"
		else
			echo \", in Nagios\"
		fi
	" # DO NOT REMOVE!

done

exit 0
