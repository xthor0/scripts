#!/bin/sh

# variable
server="jacksonhole.datamark.com"

# display usage
function usage() {
	echo "`basename $0`: Find client name from web server for domain."
	echo "Usage:

`basename $0` -d domain.com"
	exit 255
}

# get command-line args
while getopts "d:" OPTION; do
	case $OPTION in
		d) domain="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$domain" ]; then
	usage
fi

# do it
ssh $server "
	result=\`find /etc/httpd/sites-available -iname $domain | cut -d \/ -f 5\`
	if [ -z \"\$result\" ]; then
		echo "\$HOSTNAME: $domain not hosted here."
	else
		echo \"Client for $domain: \$result\"
	fi
" # do not remove

exit 0
