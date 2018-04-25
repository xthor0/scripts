#!/bin/sh

# source in servers
. /usr/local/bin/servers

# display usage
function usage() {
	echo "`basename $0`: Fix hostname so that url.com works as well as www.url.com."
	echo "Usage:

`basename $0` -c client -d url"
	exit 255
}

# get command-line args
while getopts "d:c:" OPTION; do
	case $OPTION in
		c) client="$OPTARG";;
		d) url="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$url" -o -z "$client" ]; then
	usage
fi

# verify we've got a list of servers to work with
if [ -z "$WEB_SERVERS" ]; then
	echo "Missing WEB_SERVERS variable. Dying a slow painful death."
	exit 255
fi

# do it

for server in ${WEB_SERVERS}; do
	ssh $server "echo client=$client > variables; echo url=$url >> variables"
	ssh $server '
		. variables
		# verify file exists
		if [ -f /etc/httpd/sites-available/$client/$url ]; then
			# verify it contains a line ServerName www.$url
			if [ `grep ServerName\ www.$url /etc/httpd/sites-available/$client/$url | wc -l` -ge 1 ]; then
				echo Hu3v05C@m313r05 | sudo -S sed -i s/ServerName\ www.$url/ServerName\ $url\\nServerAlias\ www.$url/g /etc/httpd/sites-available/$client/$url
				if [ $? -eq 0 ]; then
					sudo /usr/sbin/apachectl graceful
					if [ $? -eq 0 ]; then
						echo `hostname`: OK
					else
						echo `hostname`: Possible apache problem.
					fi
				else
					echo `hostname`: Error writing file.
				fi
			else
				echo `hostname`: No matching lines
			fi
		else
			echo `hostname`: $url filename does not exist.
		fi	
	' # DO NOT REMOVE THIS LINE
	ssh $server "rm -f variables"
done

exit 0
