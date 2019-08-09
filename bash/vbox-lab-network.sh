#!/bin/bash

# change this if you want a different network for your local VMs.
# this one just happens to NOT conflict with anything I use currently...
vboxnet_ip="10.187.88.1"
vboxnet_mask="255.255.255.0"

# just in case this ever changes locations...
vbm=/usr/bin/vboxmanage
ip=/usr/sbin/ip

### make sure vboxmanage is present
test -x ${vbm}
if [ $? -ne 0 ]; then
    echo "Missing vboxmanage - is virtualbox installed?"
    exit 255
fi

### vboxnet0
### this script may need to be rewritten if you have multiple host-only adapters
${vbm} list hostonlyifs | grep -q '^Name:[ \t]*vboxnet0'
if [ $? -eq 0 ]; then
    echo "vboxnet0 is already configured"
else
    # create a new vbox host only interface
    echo "vboxnet0 does not exist -- creating"
    ${vbm} hostonlyif create
    ${vbm} list hostonlyifs | grep -q '^Name:[ \t]*vboxnet0'
    if [ $? -eq 0 ]; then
        echo "vboxnet0 created successfully"
    else
        echo "error creating vboxnet0 -- exiting."
        exit 255
    fi
fi

### bring up vboxnet0
# if we don't assign the IP and netmask at every boot, vbox won't bring the interface up
# unless we actually BOOT UP a VM - and while I could script that, this was easier. :)
echo "vboxnet0 will be configured with ip ${vboxnet_ip} and netmask ${vboxnet_mask}"
${vbm} hostonlyif ipconfig vboxnet0 --ip ${vboxnet_ip} --netmask ${vboxnet_mask}
sleep 1
${vbm} list hostonlyifs | grep -A10 '^Name:[ \t]*vboxnet0' | grep -q '^Status:[ \t]*Up'
if [ $? -eq 0 ]; then
    echo "vboxnet0 configured successfully!"
else
    echo "error - vboxnet0 created, but could not be configured. exiting."
    exit 255
fi

### let's enable NAT for this network, on whatever network is active
echo "You will be prompted for your sudo password!"
gateways=$(${ip} route | grep default | wc -l)
if [ ${gateways} -eq 1 ]; then
    nat_dev=$(${ip} route | /usr/bin/grep default | /usr/bin/awk '{ print $5 }')
    natcmd="/usr/sbin/iptables -t nat -A POSTROUTING -o ${nat_dev} -j MASQUERADE"
else
    nat_dev=$(${ip} route | /usr/bin/grep default | /usr/bin/awk '{ print $9 " " $5 }' | /usr/bin/sort -n | /usr/bin/head -n1 | /usr/bin/awk '{ print $2 }')
    natcmd="/usr/sbin/iptables -t nat -A POSTROUTING -o ${nat_dev} -j MASQUERADE"
fi
echo "Enabling NAT masquerade using network device ${nat_dev}"
sudo ${natcmd}


### we're done!
exit 0
