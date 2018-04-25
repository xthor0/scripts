#!/bin/bash

# Make sure were in the right place
START_DIR="/srv/stingray/www"
TEMP_DIR="/srv/stingray/tmp"
TIME="`date +%d%m%Y_%s`"
OLD_DIR="/srv/stingray/www-${TIME}"

# check for existence of ${OLD_DIR}
if [ -d "${TEMP_DIR}" ]; then
	echo "Old directory exists, removing..."
	rm -rf "${TEMP_DIR}"
	if [ $? -ne 0 ]; then
		echo "FAILED: Unable to remove ${TEMP_DIR}."
		exit 255
	fi
fi

if [ -z "${1}" ]; then
	echo "Must specify a version number to update to."
	exit 127
fi

VER="${1}"

# Checkout the latest version
echo "Checking out Stingray version ${VER}..."
svn export svn://marzipan.datamark.com/stingray/system/tags/${VER} ${TEMP_DIR} > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Error checking out Stingray version ${VER}. Fatal error."
	exit 255
fi

svn export svn://marzipan.datamark.com/stingray/client/branches/stable ${TEMP_DIR}/classes/client > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Error checking out Stingray version ${VER} (stable branch). Fatal error."
	exit 255
fi

# Set /logs to readable
chmod 2777 ${TEMP_DIR}/logs
if [ $? -ne 0 ]; then
	echo "Error setting permissions on ${TEMP_DIR}/logs. Push process will stop now."
	exit 255
fi

# Set /locks to writable
chmod 777 ${TEMP_DIR}/cli/locks
if [ $? -ne 0 ]; then
	echo "Error setting permissions on ${TEMP_DIR}/cli/locks. Push process will stop now."
	exit 255
fi

# Set /compiled to writable
chmod 777 ${TEMP_DIR}/docroot/compiled
if [ $? -ne 0 ]; then
	echo "Error setting permissions on ${TEMP_DIR}/docroot/compiled. Push process will stop now."
	exit 255
fi

# Set /compile to writable
chmod 777 ${TEMP_DIR}/compile
if [ $? -ne 0 ]; then
	echo "Error setting permissions on ${TEMP_DIR}/docroot/compile. Push process will stop now."
	exit 255
fi

### Logs are now located in /var/log/stingray, so this should be unnecessary
# touch log file and change permissions so Apache can write to it
#touch ${TEMP_DIR}/logs/stingray.log
#if [ $? -ne 0 ]; then
#	echo "Error creating Stingray log file. Push process will stop now."
#	exit 255
#fi

#chmod 666 ${TEMP_DIR}/logs/stingray.log
#if [ $? -ne 0 ]; then
#	echo "Error setting permissions on Stingray log file. Push process will stop now."
#	exit 255
#fi

# Setup the config -- stingray.ini
if [ -f ${START_DIR}/stingray.ini ]; then
	cp ${START_DIR}/stingray.ini ${TEMP_DIR}
else
	echo "Error: Missing stingray.ini in ${START_DIR}. Push will stop now."
	exit 255
fi

# config -- log4php.xml
if [ -f ${START_DIR}/log4php.xml ]; then
	cp ${START_DIR}/log4php.xml ${TEMP_DIR}
else
	echo "Error: Missing log4php.xml in ${START_DIR}. Push will stop now."
	exit 255
fi

# modify the version string in stingray.ini
sed -i.bak "s/^version = [0-9]\{1,3\}\.[0-9]\{1,3\}\.\?[0-9]\{0,3\}\?/version = $VER/g" ${TEMP_DIR}/stingray.ini && rm -f ${TEMP_DIR}/stingray.ini.bak
if [ $? -ne 0 ]; then
	echo "Error changing the version string in stingray.ini. Not critical, so the push will continue."
fi

# change the selinux context
echo "Changing the SELinux context of the Stingray docroot..."
sudo chcon -R system_u:object_r:httpd_sys_content_t ${TEMP_DIR}
if [ $? -ne 0 ]; then
        echo " FAILED!"
        exit 1
else
        echo " Success."
fi

# Kill the lead processor
LPCount=`ps ax | grep lead_processor.php | grep -v grep | awk '{ print $1 }' | wc -l`
if [ $LPCount -eq 0 ]; then
	echo "No lead processors running on this machine."
else
	echo "Killing lead processor... you may be prompted for your password."
	ps ax | grep lead_processor.php | grep -v grep | awk '{ print $1 }' | xargs -r kill -9
	sleep 5
	LPCount=`ps ax | grep lead_processor.php | grep -v grep | awk '{ print $1 }' | wc -l`
	if [ $LPCount -eq 0 ]; then
		echo "Lead processor killed."
	else
		# Try again.
		echo "Lead Processors still running. Trying again..."
		sleep 5
		ps ax | grep lead_processor.php | grep -v grep | awk '{ print $1 }' | xargs -r kill -9
		sleep 10
		LPCount=`ps ax | grep lead_processor.php | grep -v grep | awk '{ print $1 }' | wc -l`
		if [ $LPCount -gt 0 ]; then
			echo "FAILED: ${LPCount} lead processor processes are still running."
			exit 255
		else
			echo "That got it."
		fi
	fi
fi

# Kill trigger_deliverer.php
TDCount=`ps ax | grep trigger_deliverer.php | grep -v grep | awk '{ print $1 }' | wc -l`
if [ $TDCount -eq 0 ]; then
	echo "No trigger deliverers running on this machine."
else
	echo "Killing trigger deliverer... you may be prompted for your password."
	ps ax | grep trigger_deliverer.php | grep -v grep | awk '{ print $1 }' | xargs kill -9
	sleep 5
	TDCount=`ps ax | grep trigger_deliverer.php | grep -v grep | awk '{ print $1 }' | wc -l`
	if [ $TDCount -eq 0 ]; then
		echo "Trigger deliverer killed."
	else
		echo "FAILED: Trigger deliverer processes are still running."
		exit 255
	fi
fi

# kill processing queue processor
PQCount=`ps ax | grep processing_queue_processor.php | grep -v grep | awk '{ print $1 }' | wc -l`
if [ $PQCount -eq 0 ]; then
	echo "No processing queue processors running on this machine."
else
	echo "Killing processing queue processors... you may be prompted for your password."
	ps ax | grep processing_queue_processor.php | grep -v grep | awk '{ print $1 }' | xargs kill -9
	sleep 5
	PQCount=`ps ax | grep processing_queue_processor.php | grep -v grep | awk '{ print $1 }' | wc -l`
	if [ $PQCount -eq 0 ]; then
		echo "Processing queue processor killed."
	else
		echo "FAILED: Processing queue processes are still running."
		exit 255
	fi
fi

# Move current to old && move new to live
echo "Moving old document root out of the way and new one into place..."
mv ${START_DIR} ${OLD_DIR} && mv ${TEMP_DIR} ${START_DIR}
if [ $? -ne 0 ]; then
        echo " FAILED! $HOSTNAME may be in an unstable state. Contact Infrastructure immediately."
        exit 255
else
        echo " Success."
fi

# restart apache
echo "Restarting Apache, you may be asked for your password..."
sudo /usr/sbin/apachectl graceful

echo "Successfully pushed Stingray version ${VER} to $HOSTNAME."

echo "Restarting processor scripts."
# I would like to find a way to pull this out of Cron so this would track changes there,
# but we haven't really had many changes, so I'm not sure it's really worth it.
# All app servers run this, but madrid and barcelona only run it in failover mode.
if [ $HOSTNAME == "lisbon.datamark.com" -o $HOSTNAME == "seville.datamark.com" ]; then
	su - stingray -c "(/usr/local/bin/launchLeadProcessor.sh 16 >& /dev/null &) &"
fi
# Only Lisbon and Madrid run the trigger_deliverer.php script, but Madrid has it disabled most of the time.
if [ $HOSTNAME == "lisbon.datamark.com" ]; then
	su - stingray -c "(php /srv/stingray/www/cli/trigger_deliverer.php >> /var/log/stingray/trigger_deliverer.log 2>&1 &)&"
fi
echo "Scripts are restarted."

exit 0
