#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: A simple Bash script that counts down."
	echo "Usage:

`basename $0` -s <seconds> [ -m <message> ]
-s: Seconds to wait
-m: Message to show (optional)"
	exit 255
}

# get command-line args
while getopts "s:m:" OPTION; do
	case $OPTION in
		s) seconds=${OPTARG};;
		m) message="${OPTARG}";;
		*) usage;;
	esac
done

# make sure we have correct linux tools
for binary in notify-send zenity; do
  which ${binary} >& /dev/null
  if [ $? -eq 1 ]; then
    echo "Error: missing ${binary}. Please install to use this script."
    exit 255
  fi
done

if [ -z "$seconds" ]; then
  usage
fi

if [ -z "$message" ]; then
  message="Finished!"
fi

date1=$((`date +%s` + $seconds))

while [ "$date1" -ne `date +%s` ]; do
  # echo -ne "$(date --date @$(($date1 - `date +%s` - 19800 )) +%H:%M:%S)\r"
  remains=$(expr $date1 - `date +%s`)
  echo -ne "Remaining seconds: ${remains}\r"
  sleep .1
done

notify-send 'Countdown' "$message"
zenity --info --title "Countdown" --text "$message" &

# end

