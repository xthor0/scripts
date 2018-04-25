#!/bin/bash

# usage
function usage() {
        echo "`basename $0`: Open remote desktop session to a host."
        echo "Usage:

`basename $0` -h <hostname> [ -c ] [ -w ] [ -u <username> -d <domain> -p <password> ] [ -s ] [ -a ]
-w : instead of full screen, use a window
-u : username
-p : password
-d : domain
-a : disable network level authentication (NLA)
-s : share /home/<username> with remote machine
-l : LAN bandwidth available
-P : Prompt for username and password
"
        exit 255
}

# command-line arguments
while getopts "h:u:p:d:cwsalP" OPTION; do
        case $OPTION in
                h) remote_host="$OPTARG";;
		w) windowed=1;;
		u) username="${OPTARG}";;
		p) password="${OPTARG}";;
		d) domain="${OPTARG}";;
		s) sharehome=1;;
		a) nla="-sec-nla";;
		l) lan=1;;
		P) pwprompt=1;;
                *) usage;;
        esac
done

### BEGIN
# this script should work on either OS X or Linux, and we'll make that determination based on where we find binaries
if [ -x /usr/bin/xrandr ]; then
	width=$(/usr/bin/xrandr -q 2>&1 | grep 'Screen 0' | cut -d \, -f 2 | awk '{ print $2 }')
	#fullscreen=$(/usr/bin/xrandr -q 2>&1 | grep ' connected.*+0+0' | awk '{ print $3 }' | cut -d \+ -f 1)
	rdp=/usr/bin/xfreerdp
else
	#width=$(/opt/X11/bin/xrandr -q 2>&1 | grep 'Screen 0' | cut -d \, -f 2 | awk '{ print $2 }')
	#fullscreen=$(/opt/X11/bin/xrandr -q 2>&1 | grep ' connected.*+0+0' | awk '{ print $3 }' | cut -d \+ -f 1)
	rdp=/usr/local/bin/xfreerdp
fi

# check for xfreerdp, and get version
if [ -x $rdp ]; then
	version="`$rdp --version | awk '{ print $5 }'`"
	majorver="`echo $version | cut -d \. -f 1`"
	if [ $majorver -ge 1 ]; then
		rdpopts=" /cert-ignore "
	else
		if [ -n "${nla}" ]; then
			# freerdp versions lower than 1 do not support nla
			unset nla
		fi
	fi
else
	echo "xfreerdp binary is missing. Please check the path and verify it is installed."
	exit 255
fi

# check resolution -- only important if -w option is passed
if [ -n "$windowed" ]; then
	if [ -z "$width" ]; then
		echo "Unable to determine resolution. Exiting."
		exit 255
	else
		if [ $width -eq 1366 ]; then
			resolution="1280x710"
		elif [ $width -eq 1440 ]; then
			resolution="1280x720"
		elif [ $width -eq 1680 ]; then
			resolution="1600x900"
		elif [ $width -eq 1920 ]; then
			resolution="1800x1000"
		elif [ $width -gt 1920 ]; then
			resolution="2000x1200"
		else
			resolution="1024x768"
		fi
		window=" /size:${resolution} "
	fi
else
	#window=" -g $fullscreen "
	window=" /f "
fi

# did we ask for LAN speeds?
if [ -z "${lan}" ]; then
	lan="/bpp:16"
else
	lan="/network:broadband"
fi

# check for login information
if [ -n "$pwprompt" ]; then
	# find zenity
	zenity=$(which zenity)
	if [ -z "${zenity}" ]; then
		if [ -z "$PS1" ]; then
			xmessage -center "Sorry - you don't have Zenity installed, cannot prompt for credentials"
		else
			echo "Sorry - zenity is not installed. Exiting..."
		fi
		exit 255
	fi

	# check for interactive shell
	if [ -z "$PS1" ]; then
		# non-interactive - no text prompts if Zenity is missing
		remote_host=$($zenity --entry --text "Host:")
		username=$($zenity --entry --text "Username:")
		password=$($zenity --password --text "Password:")
		domain=$($zenity --entry --text "Domain (leave blank if none):")
	else
		read -p "Host: " remote_host
		read -p "Username: " username
		read -s -p "Password: " password
		read -p "Domain: " domain
	fi

	# verify arguments
	if [ -z "$remote_host" -o -z "$username" -o -z "$password" ]; then
		if [ -z "$PS1" ]; then
			# non-interactive shell
			if [ -x /usr/bin/zenity ]; then
				zenity --info --text "Missing hostname, username, or password. Sorry, exiting."
				exit 255
			else
				xmessage -center "Missing hostname, username, or password. Sorry, exiting."
			fi
			exit 255
		else
			echo "Missing hostname, username, or password."
			usage
		fi
	else
		if [ -n "$domain" ]; then
			CREDS=" /u:${username} /p:\"${password}\" /d:${domain} "
		else
			CREDS=" /u:${username} /p:\"${password}\" "
		fi
	fi
else
	# check required arguments
	if [ -z "$remote_host" ]; then
		usage
	fi

	if [ -n "$username" -a -n "$password" ]; then
		if [ -n "$domain" ]; then
			CREDS=" /u:${username} /p:\"${password}\" /d:${domain} "
		else
			CREDS=" /u:${username} /p:\"${password}\" "
		fi
	else
		[ -f $HOME/.creds ] && . $HOME/.creds
		if [ -n "$WINUSER" ]; then
			CREDS=" /u:${WINUSER} /d:${WINDOMAIN} /p:${WINPASS} "
		else
			echo "Username and password arguments are required."
			usage
		fi
	fi
fi

# are we sharing our disk?
if [ -n "${sharehome}" ]; then
	#SHAREDISK="--plugin rdpdr --data disk:${USERNAME}:${HOME} --"
	SHAREDISK="+home-drive"
fi

# build command line
cmdLine="$rdp ${rdpopts} ${nla} ${CREDS} ${window} ${lan} +clipboard /sound:sys:alsa $SHAREDISK /v:${remote_host}"

echo "===================" >> $HOME/rdpsession.log
echo "Connecting to ${remote_host} at `date`..." >> $HOME/rdpsession.log
echo "Detected resoluion: ${width}" >> $HOME/rdpsession.log
echo "Command line: $cmdLine" >> $HOME/rdpsession.log
($cmdLine 2>&1 >> $HOME/rdpsession.log &)&

exit 0
