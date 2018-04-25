#!/bin/bash

#current_ip=$(lynx -dump checkip.dyndns.com | awk '{ print $4 }' |  sed -rn '/((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])/p')
function getIP() {
	current_ip=$(lynx -dump http://www.mypublicip.com/ | grep 'IP Address Is' | awk '{ print $5 }' | sed -rn '/((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])/p')
}

function notifyMe() {
	echo "$1"
	$HOME/Dropbox/projects/scripts/prowl.pl -apikey=fb18cb558102482e883ac76ba05a3c1b00212e96 -application="IP Check" -event="hakar.net IP address" -notification="$1" -priority=-2
}

getIP
resolved_ip=$(dig +short @8.8.8.8 hakar.net)

if [ -z "$current_ip" ]; then
	sleep 60
	getIP
	if [ -z "$current_ip" ]; then
		echo "Unable to determine current IP address."
		exit 255
	fi
fi

if [ "$current_ip" != "$resolved_ip" ]; then
	message="$(date) :: Error: hakar.net should resolve to $current_ip -- but instead resolves to $resolved_ip. You might want to correct this. :)"
	notifyMe "$message"
else
	echo "$(date) :: hakar.net is pointed to the correct IP address ($current_ip)."
fi

exit 0
