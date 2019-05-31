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

future=$((`date +%s` + $seconds))
ends=$(date -d @$future +%l:%M:%S\ %p)

while [ "$future" -ne `date +%s` ]; do
  remains=$(($future - `date +%s`))
  printf "%-12s %-15s %-20s %3d\r" "Timer ends:" "${ends}" "Seconds remaining:" ${remains}
  sleep .1
done

# newline to make formatting look nice
echo

notify-send 'Timer Done' "$message"
zenity --info --title "Timer Done" --text "$message" &

# end

