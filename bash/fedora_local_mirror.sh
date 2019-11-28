#!/bin/bash

updateDir="/var/www/html/mirror/fedora/31/x86_64/updates/" # leave the trailing slash. It's important for rsync.
logfile="${HOME}/fedora_local_mirror.log"

# just in case I need it again
# run this ONCE to create a mirror for the OS itself
# rsync -avP rsync://mirrors.xmission.com/fedora/linux/releases/31/Everything/x86_64/os/ /var/www/html/mirror/fedora/31/x86_64/os/

echo "$(date) :: Starting rsync from mirrors.xmission.com for fedora updates..." >> ${logFile}
rsync -avP --delete rsync://mirrors.xmission.com/fedora/linux/updates/31/Everything/x86_64/Packages "${updateDir}" >> ${logfile} 2>&1
if [ $? -eq 0 ]; then
  cd "${updateDir}" && createrepo . >> ${logfile} 2>&1
fi

exit 0
