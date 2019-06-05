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
if [ $? -eq 1 ]; then
    echo "vboxnet0 is not configured"
    ${vbm} hostonlyif ipconfig vboxnet0 --ip ${vboxnet_ip} --netmask ${vboxnet_mask}
    sleep 1
    ${vbm} list hostonlyifs | grep -q '^Name:[ \t]*vboxnet0'
    if [ $? -eq 1 ]; then
        echo "error - vboxnet0 still not present after configuration - exiting"
        exit 255
    fi
fi

### make sure DHCP is not turned on, stupid virtualbox...
maxattempts=2
while true; do
    let attempt += 1
    echo "vboxnet0 DHCP check # ${attempt}"
    dhcp_status=$(${vbm} list hostonlyifs | grep -A2 '^Name:[ \t]*vboxnet0' | grep ^DHCP | awk '{ print $2 }')
    if [ "${dhcp_status}" == "Disabled" ]; then
        break
    else
        if [ ${attempt} -gt ${maxattempts} ]; then
            echo "I give up - I tried to fix DHCP on vboxnet0, but I can't. Exiting."
            exit 255
        else
            ${vbm} hostonlyif ipconfig vboxnet0 --ip ${vboxnet_ip} --netmask ${vboxnet_mask}
            sleep 1
        fi
    fi
done

### let's enable NAT for this network, on whatever network is active
gateways=$(${ip} route | grep default | wc -l)
if [ ${gateways} -eq 1 ]; then
    /usr/sbin/iptables -t nat -A POSTROUTING -o $(${ip} route | /usr/bin/grep default | /usr/bin/awk '{ print $5 }') -j MASQUERADE
else
    /usr/sbin/iptables -t nat -A POSTROUTING -o $(${ip} route | /usr/bin/grep default | /usr/bin/awk '{ print $9 " " $5 }' | /usr/bin/sort -n | /usr/bin/head -n1 | /usr/bin/awk '{ print $2 }') -j MASQUERADE
fi

### we're done!
exit 0