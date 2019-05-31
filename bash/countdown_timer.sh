#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: A simple Bash script that counts down."
	echo "Usage:

`basename $0` -s <seconds> [ -m <message> ]
-t: Time measurement (10s, 5m, 6h, 2d - don't ask me why I implemented days, I doubt I'll ever use it)
-m: Message to show (optional)"
	exit 255
}

# get command-line args
while getopts "t:m:" OPTION; do
	case $OPTION in
		t) time=${OPTARG};;
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

if [ -z "${time}" ]; then
  usage
fi

if [ -z "$message" ]; then
  message="Finished!"
fi

# convert time unit to seconds
i=$((${#time}-1))
unit="${time:$i:1}"
value="${time:0:$i}"

case "${unit}" in
  s) seconds=${value};;
  m) seconds=$((${value} * 60));;
  h) seconds=$((${value} * 3600));;
  d) seconds=$((${value} * 86400));;
  *) usage;;
esac

future=$((`date +%s` + $seconds))
#ends=$(date -d @$future +%l:%M:%S\ %p)
ends=$(date -d @$future)

while [ "$future" -ne `date +%s` ]; do
  remains=$(($future - `date +%s`))
  printf "%-12s %-35s %-20s %3d\r" "Timer ends:" "${ends}" "Seconds remaining:" ${remains}
  sleep .1
done

# newline to make formatting look nice
echo

notify-send 'Timer Done' "$message"
zenity --info --title "Timer Done" --text "$message" &

# end

