#!/bin/sh

WebPoolIP="66.133.120.242"
failWebPoolIP="206.173.159.200"
sunset_title="<title>Site or Page Not Available!</title>"
dead_title="<title>phpinfo()</title>"

# display usage
function usage() {
	echo "`basename $0`: Check to see if a domain is pointed at our web pool and sunsetted."
	echo "Usage:

`basename $0` -F <path/to/textfile> [ -d ]

Text file should contain a list of domains, one per line."
	exit 255
}

# get command-line args
while getopts "F:d" OPTION; do
	case $OPTION in
		F) inputFile="$OPTARG";;
		d) DEBUG=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$inputFile" ]; then
	usage
fi

# Does the input file exist?
if [ ! -f "${inputFile}" ]; then
	echo "I can't find $inputFile -- sorry!"
	exit 255
fi

# if debugging is set, we stop after 10 domains
if [ -n "${DEBUG}" ]; then
	stop_count=50
fi

# process the list!
total_count=`cat "${inputFile}" | wc -l`
echo "Processing ${total_count} domains"
count=0
skip_count=0
while read domain; do
	# null record check -- skip these
	if [ -z "$domain" ]; then
		let skip_count+=1
		continue
	fi

	# increment record count
	let count+=1

	# see if the A record exists and is pointed at DM
	a_record="`dig ${domain} @8.8.8.8 | grep -A1 ';; ANSWER SECTION' | grep ${domain} | awk '{ print $5 }'`"

	if [ "$a_record" == "$WebPoolIP" ]; then
		dns_status="OK"

		# pull the site and check title
		site_content="`echo -e \"GET / HTTP/1.0\nhost: ${domain}\n\" | nc ${domain} 80`"
		site_title="`echo ${site_content} | grep -o '<title>.*</title>'`"
		if [ "$site_title" == "$sunset_title" ]; then
			title_status="OK"
		else
			redirect="`echo ${site_content} | grep -o 'Location: sunset/index.html' | wc -l`"
			if [ $redirect -eq 1 ]; then
				title_status="OK"
			else
				title_status="FAILED"
			fi
		fi
	else
		dns_status="FAILED"
		title_status="N/A"
		# nothing more to check from here
	fi

	# the domains we need to be concerned about are pointed at our web pool, but the title is not sunsetted.
	if [ "$dns_status" == "OK" -a "$title_status" == "FAILED" ]; then
		domains_to_check="$domains_to_check $domain"
		flag="<--CHECK"
	else
		domains_to_remove="$domains_to_remove $domain"
		flag=""
	fi

	# output results
	printf "[%04d] %-40s %s: %-10s %s: %-7s %s\n" $count $domain DNS $dns_status Title $title_status $flag

	# debugging
	if [ -n "${stop_count}" ]; then
		if [ ${count} -ge ${stop_count} ]; then
			echo "Stop count of ${stop_count} reached -- exiting!"
			exit 0
		fi
	fi
done < "${inputFile}"

# report status
if [ $skip_count -gt 0 ]; then
	echo "Skipped records: $skip_count"
	echo
fi

if [ -n "${domains_to_check}" ]; then
	echo "These domains are functioning properly:"
	echo ${domains_to_check}
	echo
fi

echo "These domains should be removed from Nagios and the web pool:"
echo $domains_to_remove

# end of script
exit 0
