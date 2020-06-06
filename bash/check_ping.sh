#!/bin/bash

### crontab example
# */5 * * * * /home/xthor/scripts/check_ping.sh -u <pushover USER token> -a <pushover APP token> -c 'host1 host2 etc'

# display usage
function usage() {
	echo "`basename $0`: make sure the internet worky worky."
	echo "Usage:

`basename $0` -u <pushover user token> -a <pushover app token> -c 'host.1.fqdn host.2.fqdn'

HOSTS SPECIFIED IN -c MUST BE SINGLE QUOTED
"
	exit 255
}

# get command-line args
while getopts "u:a:c:v" OPTION; do
	case $OPTION in
		u) userToken="$OPTARG";;
		a) appToken="$OPTARG";;
		c) HOSTS_TO_CHECK="${OPTARG}";;
		v) verbose=1;;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "${userToken}" -o -z "${appToken}" -o -z "${HOSTS_TO_CHECK}" ]; then
	usage
fi

# set some defaults we'll use later
where_am_i=$(readlink -f $0)
loc=$(dirname ${where_am_i})
logDir=${loc}/logs
logFile=${logDir}/$(date +%Y%m%d).log
mtrLog=${logDir}/$(date +%Y%m%d)-mtr.log
errLog=${logDir}/$(date +%Y%m%d)-err.log
ip_file=${loc}/.current_ip

# does the log dir exist? if not, create it
if [ ! -d "${logDir}" ]; then
	mkdir -p ${logDir}
	if [ $? -ne 0 ]; then
		echo "ERROR: Couldn't create ${logDir} -- exiting!"
		exit 255
	fi
fi

# makes the logs look nicer
function message() {
	if [ -z "${verbose}" ]; then
		echo "$(basename $0) :: $(date) :: $*" >> ${logFile}
	else
		# show output *AND* log it
		echo "$(basename $0) :: $(date) :: $*" | tee -a ${logFile}
	fi
}

function pushover_message() {
	curl -s --form-string "token=${appToken}" --form-string "user=${userToken}" --form-string "message=$(basename $0) :: ${HOSTNAME} :: $*" https://api.pushover.net/1/messages.json >> ${errLog} 2>&1
}

echo "$(basename $0) :: $(date) :: START" >> ${mtrLog}
echo "$(basename $0) :: $(date) :: START" >> ${errLog}
message "Begin!"

# we need to find MTR. Why does every. effing. distro. do this differently.
if [ -x /usr/sbin/mtr ]; then
	mtr=/usr/sbin/mtr
elif [ -x /usr/bin/mtr ]; then
	mtr=/usr/bin/mtr
else
	message "I can't find MTR, detailed reporting will fail."
fi

# did our IP change?
CURRENT_IP=$(/usr/sbin/ip route get 8.8.8.8 | head -n1 | awk '{ print $7 }')
if [ -f "${ip_file}" ]; then
	OLD_IP=$(cat "${ip_file}")
	grep -q ${CURRENT_IP} "${ip_file}"
	if [ $? -eq 1 ]; then
		echo ${CURRENT_IP} > "${ip_file}"
		message "IP changed. Old IP: ${OLD_IP} :: New IP: ${CURRENT_IP}"
		message "Sending Pushover message, too."
		pushover_message "IP changed. Old IP: ${OLD_IP} :: New IP: ${CURRENT_IP}"
	else
		message "IP hasn't changed. Old IP: ${OLD_IP} :: New IP: ${CURRENT_IP}"
	fi
else
	message "Hey, first time run! Recording current IP address of ${CURRENT_IP}, and sending pushover message."
	echo ${CURRENT_IP} > "${ip_file}"
	pushover_message "Hello from ${HOSTNAME} on ${CURRENT_IP}!"
fi

# let's check connectivity to some hosts
for host in ${HOSTS_TO_CHECK}; do
	# check for packet loss first
	message "Pinging ${host} (5 packets)..."
	ping -c5 -w5 -q ${host} >> ${errLog} 2>&1
	if [ $? -eq 0 ]; then
		message "OK!"
	else
		# I've been seeing this fail to Google with a single packet lost...
		# so, ping it again, and if it's still failing THEN MTR
		message "Ping check failed, trying again..."
		ping -c5 -w5 -q ${host} >> ${errLog} 2>&1
		if [ $? -eq 0 ]; then
			message "Ping check OK (second attempt)"
		else
			# mtr report just for gits and shiggles
			message "ERROR!"
			message "Running MTR report..."
			${mtr} -n -c 10 -r ${host} >> ${mtrLog} 2>> ${errLog}

			# send pushover message, too
			send_pushover=1
		fi
	fi
done

# I didn't put this in the for loop, because I don't want to clobber the pushover API over and over
if [ -n "${send_pushover}" ]; then
	message "Sending pushover notification."
	pushover_message "ERROR: ping checks failed from ${HOSTNAME} -- please check logs!"
fi

echo "$(basename $0) :: $(date) :: END" >> ${mtrLog}
echo "$(basename $0) :: $(date) :: END" >> ${errLog}
message "End!"

exit 0
