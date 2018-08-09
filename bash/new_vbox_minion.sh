#!/bin/bash

# get command-line args
while getopts "n:" OPTION; do
  case $OPTION in
    n) vmname_prefix="$OPTARG";;
    *) usage;;
  esac
done

# generate a VM name that starts with the string provided
if [ -z "${vmname_prefix}" ]; then
  echo "Error: -n option not specified! Exiting..."
  exit 255
else
  seed=$(date | md5sum)
  vmname="${vmname_prefix}-${seed:0:10}"
fi

# change if the template root password changes
sshpasswd="p@ssw0rd"

# options passed to ssh
sshopts="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# the new VM gets created by importing a CentOS 7 OVA that I built - this is a hack, I wish salt-cloud + virtualbox was working
vboxmanage import --vsys 0 --vmname ${vmname} --vsys 0 --cpus 2 --vsys 0 --memory 4096 --vsys 0 --unit 10 --disk /storage/vbox/${vmname}/${vmname}.vmdk /storage/vbox/ova/cent7template.ova
vboxmanage modifyvm ${vmname} --nic1 hostonly --hostonlyadapter1 vboxnet0
vboxmanage startvm ${vmname} --type headless

# get the MAC address of this VM
macaddress=$(grep MACAddress /storage/vbox/${vmname}/${vmname}.vbox | awk '{ print $4 }' | cut -d \" -f 2)

# change the format to include :
macformatted="${macaddress:0:2}:${macaddress:2:2}:${macaddress:4:2}:${macaddress:6:2}:${macaddress:8:2}:${macaddress:10:2}"

# lowercase
realmac=$(echo $macformatted | tr [:upper:] [:lower:])

# find the MAC address in /var/log/messages - this takes a bit
macfindattempt=0
macfindattemptmax=60 # we wait up to 2 minutes for the VM to boot up
while [ ${macfindattempt} -lt ${macfindattemptmax} ]; do
  let macfindattempt+=1
  if [ ${macfindattempt} -gt ${macfindattemptmax} ]; then
    echo "Max attempts reached -- exiting!"
    exit 255
  fi

  grep -q dnsmasq.*DHCPACK.*${realmac} /var/log/messages
  if [ $? -eq 0 ]; then
    ipaddr=$(grep dnsmasq.*DHCPACK.*${realmac} /var/log/messages | awk '{ print $7 }')
    break
  else
    echo "Waiting for VM to boot up... (attempt ${macfindattempt} of ${macfindattemptmax})"
    sleep 2
  fi
done

# once the machine is live, we will need to execute some commands
# but let's see if the VM works first :)
echo "Machine has booted - IP address is ${ipaddr}"

# make sure that SSH is working - may require a second or 2
while true; do
  echo "Waiting for SSH on ${ipaddr}... "
  sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} whoami
  if [ $? -eq 0 ]; then
    echo "Success!"
    break
  else
    sleep 2
  fi
done

# change the hostname
sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} hostnamectl set-hostname ${vmname}.localdev
if [ $? -ne 0 ]; then
  echo "Error changing hostname of new minion -- exiting!"
  exit 255
fi

# push installation script over to the minion
sshpass -p ${sshpasswd} scp ${sshopts} /storage/vbox/ova/setup_minion.sh root@${ipaddr}:/tmp
if [ $? -ne 0 ]; then
  echo "Error copying /storage/vbox/ova/setup_minion.sh to ${ipaddr} -- exiting!"
  exit 255
fi

# execute the script
sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} bash /tmp/setup_minion.sh
if [ $? -ne 0 ]; then
  echo "Error configuring minion at ${ipaddr} -- exiting!"
  exit 255
fi

# if we don't tell the machine to renew the DHCP lease, DNS doesn't get updated right
netdev=$(sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} "ip route" | grep default | awk '{ print $5 }')
if [ $? -eq 0 ]; then
  sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} nmcli con up ${netdev}
else
  echo "Unable to determine default network device - DNS may not work properly for this minion."
fi

# we're done
echo "Minion setup complete!"
exit 0

