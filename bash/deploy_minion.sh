#!/bin/bash

# meant to be run via systemd on a vbox minion
# an easier way to deploy since salt-cloud doesn't work

newHostName=$(VBoxControl --nologo guestproperty get GuestName | awk '{ print $2 }')

# make sure the result isn't zero length (indicating VBoxControl doesn't work), or "value" (not set)
if [ ${#newHostName} -eq 0 ]; then
  echo "vbox guest property not set - exiting."
  exit 255
elif [ "${newHostName}" == "value" ]; then
  echo "vbox guest property not set - exiting."
  exit 255
fi

# set the hostname
hostnamectl set-hostname ${newHostName}.lab

# point the minion at the right master
echo "master: 10.187.88.10" | tee /etc/salt/minion

# start/enable Salt
systemctl enable salt-minion
systemctl start salt-minion

# get rid of the evidence
systemctl disable saltdeploy
rm /etc/systemd/system/saltdeploy.service
rm /opt/deploy_minion.sh

# fin
exit 0

