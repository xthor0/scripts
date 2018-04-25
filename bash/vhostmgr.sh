#!/bin/bash

SITES_AVAILABLE="/etc/httpd/sites-available"
SITES_ACTIVE="/etc/httpd/sites-enabled"
SITES_DOMAIN=""
SITES_BASE="/home/webdocs"
SRV_IP="*"
RECIPIENTS="linuxadmins@datamark.com"
SUNSET_PATH="/home/webdocs/rmtesting/public_html/sites/sunset"

##### DO NOT MODIFY BELOW THIS POINT #####

HOSTNAME=""
DOCROOT=""
OLD_DOCROOT=""
APACHECTL="/usr/sbin/apachectl"
SENDMAIL="/usr/sbin/sendmail"
AVAIL_FILE=""
ACTIV_FILE=""

function usage()
{
	echo "Usage: $0 (action) (client) (hostname) [document root]"
	echo -e "\tActions are:"
	echo -e "\tcreate: Create a virtual host within (client) with (hostname) and (document root)"
	echo -e "\tdestroy: Destroy (client's) virtual host (hostname)"
	echo -e "\tactivate: Activate (client's) previously inactive (hostname)"
	echo -e "\tinactivate: Inactivate (client's) previously active (hostname)"
	echo -e "\tdocroot: Change (client) existing (hostname's) DocumentRoot to (document root)"
	echo -e "\tsunset: Set (client) site (hostname) to point to the 'this site is no longer active' content"
}


function prep_check()
{
	[ "x${CLIENT}" != "x" ] || {
		echo "Error! Missing client!"
		usage
		exit 3
	}
	[ -d ${SITES_AVAILABLE}/${CLIENT} ] || {
		echo "Error! Client ${CLIENT} does not exist."
		exit 4
	}
	[ "x${HOSTNAME}" != "x" ] || {
		echo "Error! Missing hostname!"
		usage
		exit 3
	}

	HOSTNAME=`echo ${HOSTNAME} | tr A-Z a-z`

	case ${HOSTNAME} in
		www.*)
			tmpHOSTNAME=`echo ${HOSTNAME} | cut -b5-`
			HOSTNAME=${tmpHOSTNAME}
			;;
	esac
	
	AVAIL_FILE="${SITES_AVAILABLE}/${CLIENT}/${HOSTNAME}"
	ACTIV_FILE="${SITES_ACTIVE}/${CLIENT}-${HOSTNAME}.conf"
}


function activate()
{
	if [ -f ${AVAIL_FILE} ]; then
		ln -s ${AVAIL_FILE} ${ACTIV_FILE}
	else
		echo "Error! ${CLIENT} - ${HOSTNAME} config file not found. Nothing to activate."
		exit 4
	fi
	[ -f ${ACTIV_FILE} ] && ${APACHECTL} graceful && echo "Site (${CLIENT}:${HOSTNAME}) successfully activated."

	sendemail "activate" "none"
}


function deactivate()
{
	if [ -f ${ACTIV_FILE} ]; then
		rm -f ${ACTIV_FILE} && \
		${APACHECTL} graceful && \
		echo "Site (${CLIENT}:${HOSTNAME}) successfully deactivated." && \
		sendemail "deactivate" "none"
	else
		echo "No active site found for ${HOSTNAME} belonging to ${CLIENT}."
	fi
}


function create()
{
	NAME=${HOSTNAME}
	if [ ${WILDCARD} -eq 1 ]; then
		WWW='*'
	else
		WWW='www'
	fi

	if [ "x${DOCROOT}" == "x" ]; then
		echo "Error! Missing document root!"
		usage
		exit 3
	fi
	if [ ! -d ${DOCROOT} ]; then
		echo "Error! Document root specified (${DOCROOT}) does not exist!"
		exit 4
	fi

	if [ -f ${AVAIL_FILE} ]; then
		echo "Config file for $HOSTNAME already exists.  Will not overwrite."
		exit 5
	fi

	SHORTNAME=`echo $HOSTNAME|cut -d. -f1`

	echo "<VirtualHost ${SRV_IP}:80>
ServerAdmin webmaster@datamark.com
DocumentRoot ${DOCROOT}
ServerName ${HOSTNAME}
ServerAlias ${WWW}.${HOSTNAME}
<Directory ${DOCROOT}>
	AddHandler cgi-script .cgi .pl
	AllowOverride All
	Options  FollowSymLinks ExecCGI
	Order allow,deny
	Allow from all
</Directory>
</VirtualHost>
" > ${AVAIL_FILE}

	mkdir -p ${DOCROOT}
	if [ ! -f ${DOCROOT}/index.html ]; then
		[ -f ${DOCROOT}/index.php ] || echo "Temporary site for ${SHORTNAME}" > ${DOCROOT}/index.php
	fi
	chgrp -R webdocs ${DOCROOT}
	chmod 775 ${DOCROOT}

	mkdir -p /var/log/httpd/vhosts/${CLIENT}/

	echo "Site (${CLIENT}:${HOSTNAME}) successfully created."

	sendemail "create" "SHORTNAME=${SHORTNAME}"

	if [ -f ${AVAIL_FILE} ]; then
		if [ ${YES_PLEASE} -ne 1 ]; then
			echo -n 'Activate? (Y/n) '
			read ACTIV
			[ x${ACTIV} != 'xn' ] && activate
		else
			activate
		fi
	fi
}


function destroy()
{
	if [ -f ${AVAIL_FILE} ]; then
		echo -en "\aWarning! This will PERMANENTLY REMOVE the site ${HOSTNAME}! Are you sure? (y/N) "
		read CONFIRM
		if [ x${CONFIRM} == 'xy' ]; then
			rm -f ${ACTIV_FILE} ${AVAIL_FILE}
			echo "Site ${CLIENT}:${HOSTNAME} PERMANENTLY removed."
			sendemail "destroy" "none"
		else
			echo "Site ${CLIENT}:${HOSTNAME} NOT removed."
		fi
	fi
}


function set_docroot()
{
	SRC_FILE="${AVAIL_FILE}"
	DST_FILE="${SRC_FILE}.1"

	NEW_DOCROOT="${DOCROOT}"

	if [ ! -d ${NEW_DOCROOT} ]; then
		echo "Error! Document root specified (${NEW_DOCROOT}) does not exist!"
		exit 4
	fi

	INDENT=0
	DOINDENT=0

	if [ -f ${SRC_FILE} ]; then
		echo -n > ${DST_FILE}

		while read LINE; do
			case ${LINE} in
				DocumentRoot*)
					OLD_DOCROOT="`echo ${LINE} | cut -d\  -f2`"
					LINE="DocumentRoot ${NEW_DOCROOT}"
					;;
				"<Directory"*)
					let INDENT=${INDENT}+1
					# This is intentional
					DOINDENT=-1
					LINE="<Directory ${NEW_DOCROOT}>"
					;;
				"</Directory>")
					let INDENT=${INDENT}-1
					[ ${INDENT} -eq 0 ] && DOINDENT=0
					;;
			esac
			if [ ${DOINDENT} -eq 1 ]; then
				for i in `seq 1 ${INDENT}`; do
					echo -ne "\t" >> ${DST_FILE}
				done
			fi
			[ ${DOINDENT} -eq -1 ] && DOINDENT=1
			echo ${LINE} >> ${DST_FILE}
		done < ${SRC_FILE}
		mv -f ${DST_FILE} ${SRC_FILE}

		${APACHECTL} graceful && echo "Successfully changed ${CLIENT}:${HOSTNAME} document root to ${NEW_DOCROOT}."

		sendemail "set_docroot" "OLD_DOCROOT=${OLD_DOCROOT}"
	else
		echo "Error! Cannot read VHost file ${SRC_FILE}!"
		exit 3
	fi
}


function sunset()
{
	TATTLED=y
	set_docroot >& /dev/null
	echo "Site ${CLIENT}:${HOSTNAME} has been retired."
	TATTLED=n
	sendemail "sunset" "OLD_DOCROOT=${OLD_DOCROOT}"
}


function getdocroot()
{
	SHORTNAME=`echo $HOSTNAME|cut -d. -f1`

	if [ x"${1}" == x ]; then
		DOCROOT="${SITES_BASE}/${CLIENT}/sites/${SHORTNAME}/public_html"
	else
		DOCROOT="${1}"
	fi
	echo "${DOCROOT}"
}

TATTLED=n

function sendemail()
{
	ACT=${1}
	ADDLINFO=${2}
	ME=`whoami`
	MINE=`hostname --fqdn`
	DATE=`date`

	if [ ${TATTLED} == 'y' ]; then
		return
	else
		TATTLED=y
	fi


	echo -e "From: droid@${MINE}
To: ${RECIPIENTS}
Subject: ${ACT} performed ${DATE}

This e-mail is just to inform you that ${ME} ran ${ACT} on ${MINE} at ${DATE}.  Data dump follows.

ACTION=${ACT}
CLIENT=${CLIENT}
HOSTNAME=${HOSTNAME}
DOCROOT=${DOCROOT}
Additional Information:
${ADDLINFO}

-Datamark Droid" | ${SENDMAIL} -t
}


if [ x${1} == 'x' ]; then
	usage
	exit 1
else
	ACTION=${1}
fi

YES_PLEASE=0
if [ x${2} == 'x-y' ]; then
	YES_PLEASE=1
	shift
fi

WILDCARD=0
if [ x${2} == 'x-w' ]; then
	WILDCARD=1
	shift
fi

CLIENT=${2}
HOSTNAME=${3}
prep_check

case $ACTION in
	CREATE|create)
		DOCROOT=`getdocroot ${4}`
		create
		;;
	DESTROY|destroy)
		destroy
		;;
	ACTIVATE|activate|ENABLE|enable)
		activate
		;;
	DEACTIVATE|deactivate|INACTIVATE|inactivate|DISABLE|disable)
		deactivate
		;;
	DOCROOT|docroot)
		DOCROOT=`getdocroot ${4}`
		set_docroot
		;;
	SUNSET|sunset)
		DOCROOT=${SUNSET_PATH}
		sunset
		;;
	*)
		echo "Error! I do not know how to $ACTION."
		exit 2
		;;
esac
