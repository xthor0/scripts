#!/bin/bash
#
# firstboot:         virtualbox custom firstboot for CentOS 6
#
# chkconfig: 35 99 95
#
# description:       Sets up a vbox machine, configures the name, and starts Salt minion
#
# prep work:
# 1. install VirtualBox guest additions
# 2. install salt repo for cent6
# 3. install salt-minion with yum
# 4. put this file in as /etc/rc.d/init.d/firstboot
# 5. chmod 755 /etc/rc.d/init.d/firstboot
# 6. chkconfig firstboot on

# stop RHGB
/usr/bin/rhgb-client --quit

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
sed -i "s/^HOSTNAME=.*/HOSTNAME=${newHostName}.lab/g" /etc/sysconfig/network

# make Salt start at boot
chkconfig salt-minion on

# append master info to /etc/salt/minion
echo "master: 10.187.88.10" | tee /etc/salt/minion

# nuke the old file so that the new NIC is not eth1
rm -f /etc/udev/rules.d/70-persistent-net.rules

# set the MAC address correctly, to match the new NIC
MACADDR=$(ip a show dev eth1 | grep 'link/ether' | awk '{ print $2 }')
sed -i "s/^HWADDR=.*/HWADDR=${MACADDR}/g" /etc/sysconfig/network-scripts/ifcfg-eth0

# turn this script off
chkconfig firstboot off

# reboot
( sleep 5; reboot &)&

# fin
exit 0

