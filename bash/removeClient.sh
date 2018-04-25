#!/bin/bash

# we need some variables
. /usr/local/bin/servers

# do we have credentials?
. $HOME/.credentials

# other variables we get right from this script
ARCHIVEDIR="$HOME/archive"
NAGIOSSVR="amsterdam.datamark.com"
ARCHIVEDEST="/cygdrive/i/To Be Archived/Archived Clients"
publicWebPoolIP="66.133.120.242"
failoverWebPoolIP="206.173.159.200"

# display usage
function usage() {
	echo "`basename $0`: Clean up a client and all associated crap from web/app servers."
	echo "Usage:

`basename $0` -c <client> -t <ticketID> -h <domain> (multiple domains MUST be enclosed in
quotes, i.e. -h \"domain1 domain2 domain3\""
	exit 255
}

# get command-line args
while getopts "c:h:P:t:" OPTION; do
	case $OPTION in
		c) client="$OPTARG";;
		h) domainList="$OPTARG";;
		P) sudoPass="$OPTARG";;
		t) ticketID="$OPTARG";;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "$client" -o -z "$ticketID" ]; then
	usage
fi

# if we have a $password variable, set sudoPass accordingly
if [ -n "$password" ]; then
	sudoPass=$password
fi

# get password here if not specified via switch
while [ -z "$sudoPass" ]; do
	echo "Please enter your sudo password: "
	read -s sudoPass
done

###############
#### BEGIN ####
###############

##############################
### 1) Archive client data ###
##############################

rm -rf $ARCHIVEDIR
mkdir -p $ARCHIVEDIR
pushd $ARCHIVEDIR

echo -e "###########\nBeginning rsync process for $client...\n##########"
for WEBSRVR in ${WEB_SERVERS}; do
	ssh $WEBSRVR "if ! [ -d /home/webdocs/\"$client\" ]; then exit 1; fi"
	if [ $? -eq 0 ]; then
		rsync -azH ${WEBSRVR}:/home/webdocs/"${client}"/ "${client}"/
	fi
done

for APPSRVR in ${APP_SERVERS}; do
	ssh $APPSRVR "if ! [ -d /home/webdocs/site2/\"$client\" ]; then exit 1; fi"
	if [ $? -eq 0 ]; then
		rsync -azH ${APPSRVR}:/home/webdocs/site2/"${client}" site2
	fi
	ssh $APPSRVR "if ! [ -d /home/webdocs/delivery_data/\"$client\" ]; then exit 1; fi"
	if [ $? -eq 0 ]; then
		rsync -azH ${APPSRVR}:/home/webdocs/delivery_data/"${client}" delivery_data
	fi
done

echo -e "###########\nBeginning tar process for $client...\n##########"
tar cf - * | bzip2 -9 > ../${client}.tar.bz2
if [ $? -eq 0 ]; then
	if [ -f ../${client}.tar.bz2 ]; then
		mv ../${client}.tar.bz2 "$ARCHIVEDEST"
	else
		echo "Missing archive file. I die now."
	fi
else
	echo "Error during archival process. Check the output."
fi

popd
if [ -f "$ARCHIVEDEST/${client}.tar.bz2" ]; then
	rm -rf $ARCHIVEDIR
	echo "#####################################
Archival of $client completed.
####################################"
else
	echo "Missing archive file: $ARCHIVEDEST/${client}.tar.bz2 -- I can't proceed."
	exit 255
fi

###################################
### 2) Remove sites from Nagios ###
###################################

if [ -n "$domainList" ]; then
	ssh $NAGIOSSVR "echo $sudoPass | sudo -S nagiosmgr.sh destroy $domainList"
	if [ $? -ne 0 ]; then
		echo "Error running nagiosmgr.sh on $NAGIOSSVR. Client removal will stop now."
		exit 255
	else
		echo -e "####################\nDomains $domainList removed from Nagios.\n####################"
	fi
fi

##################################################################
### 3) Determine if we are sunsetting or destroying the domain ###
##################################################################

for domain in $domainList; do
	currentIP="`host $domain | grep 'has address' | awk '{ print $4 }'`"
	if [ "$currentIP" == "$publicWebPoolIP" -o "$currentIP" == "$failoverWebPoolIP" ]; then
		global_vhostmgr.sh -a sunset -c $client -h $domain -P $sudoPass
		echo "$domain sunsetted."
	else
		global_vhostmgr.sh -a destroy -c $client -h $domain -P $sudoPass
		echo "$domain destroyed. (not pointed at our web pool)"
	fi
	echo -e "####################\nDomains $domainList removed from vhosts.\n####################"
done

#############################################################
### 4) Remove $client.datamark.com from Nagios and vhosts ###
#############################################################

ssh $NAGIOSSVR "echo $sudoPass | sudo -S nagiosmgr.sh destroy $client.datamark.com"
global_vhostmgr.sh -a destroy -h $client.datamark.com -c datamark -P $sudoPass
echo -e "####################\nDomain $client.datamark.com removed from Nagios and Vhosts.\n####################"

#######################################################
### 5) Clean up the directories on the live servers ###
#######################################################

echo -e "####################\nRemoving $client files from web servers...\n####################"
echo -n "Completed servers: "
for server in $WEB_SERVERS; do
	ssh $server "cd /home/webdocs
	if [ -d $client ]; then
		echo $sudoPass | sudo -S rm -rf $client
	fi
	" # END SSH SESSION
	if [ $? -eq 0 ]; then
		echo -n "$server "
	else
		echo "Error removing $client from $server! Dying now, to prevent further errors."
		exit 255
	fi
done
echo
echo -e "####################\n$client Done!\n####################"

echo -e "####################\nRemoving $client files from app servers...\n####################"
echo -n "Completed servers: "
for server in $APP_SERVERS; do
	ssh $server "cd /home/webdocs/site2
	if [ -d $client ]; then
		echo $sudoPass | sudo -S rm -rf $client
	fi

	cd /home/webdocs/delivery_data
	if [ -d $client ]; then
		echo $sudoPass | sudo -S rm -rf $client
	fi
	" # END SSH SESSION
	if [ $? -eq 0 ]; then
		echo -n "$server "
	else
		echo "Error removing $client from $server! Dying now, to prevent further errors."
		exit 255
	fi
done
echo
echo -e "####################\n$client files removed from app servers.\n####################"

#################################
### 6) Close the ticket in RT ###
#################################

ssh wendover.datamark.com "export RTUSER=bbrown; export RTPASSWD=r0ck0n; export RTSERVER=http://rt.datamark.com;
/usr/bin/rt correspond -m \"Client $client has been removed.\" $ticketID
if [ \$? -eq 0 ]; then
	/usr/bin/rt edit ticket/$ticketID set status='resolved'
	if [ \$? -eq 0 ]; then
		echo \"Ticket $ticketID closed.\"
	else
		echo \"Error closing ticket $ticketID.\"
	fi
else
	echo \"Error adding comment to ticket $ticketID.\"
fi
" # END SSH SESSION

###############
### The End ###
###############

exit 0
