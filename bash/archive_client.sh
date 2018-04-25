#!/bin/sh

CLIENT="${1}"
ARCHIVEDIR="$HOME/archive"

if [ -z "$CLIENT" ]; then
	echo "Please provide a client name on the command line."
	exit 255
fi

. /usr/local/bin/servers

rm -rf $ARCHIVEDIR
mkdir -p $ARCHIVEDIR
pushd $ARCHIVEDIR

for WEBSRVR in ${WEB_SERVERS}; do
	rsync -avzPH ${WEBSRVR}:/home/webdocs/"${CLIENT}"/ "${CLIENT}"/
done

for APPSRVR in ${APP_SERVERS}; do
	rsync -avzPH ${APPSRVR}:/home/webdocs/site2/"${CLIENT}" site2
	rsync -avzPH ${APPSRVR}:/home/webdocs/delivery_data/"${CLIENT}" delivery_data
done

tar cfv - * | bzip2 -9 > ../${CLIENT}.tar.bz2
if [ $? -eq 0 ]; then
	if [ -f ../${CLIENT}.tar.bz2 ]; then
		mv ../${CLIENT}.tar.bz2 "$HOME/WinHome/Desktop"
	else
		echo "Missing archive file. I die now."
	fi
else
	echo "Error during archival process. Check the output."
fi

popd

rm -rf $ARCHIVEDIR

