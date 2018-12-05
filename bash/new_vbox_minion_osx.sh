#!/bin/bash

# get command-line args
while getopts "n:" OPTION; do
  case $OPTION in
    n) vmname="$OPTARG";;
    *) usage;;
  esac
done

# exit if vmname is not specified
if [ -z "${vmname}" ]; then
  echo "Error: -n option not specified! Exiting..."
  exit 255
fi

# change if the template root password changes
sshpasswd="r0ck0n"

# options passed to ssh
sshopts="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# make sure vmname doesn't exist
if [ -f "${HOME}/VirtualBox VMs/${vmname}/${vmname}.vmdk" ]; then
    echo "Sorry, ${vmname} already exists. Exiting."
    exit 255
fi

# get sudo password now...
echo "We're going to execute 'nmap' with sudo privileges to find the VM."
echo "Please enter your sudo password when prompted."
sudo whoami

# the new VM gets created by importing a CentOS 7 OVA that I built - this is a hack, I wish salt-cloud + virtualbox was working
vboxmanage import --vsys 0 --vmname ${vmname} --vsys 0 --cpus 1 --vsys 0 --memory 1024 --vsys 0 --unit 11 --disk ${HOME}/"VirtualBox VMs"/${vmname}/${vmname}.vmdk ${HOME}/cent7template.ova
if [ $? -ne 0 ]; then
    echo "Error importing ova template. Exiting."
    exit 255
fi

vboxmanage modifyvm ${vmname} --nic1 hostonly --hostonlyadapter1 vboxnet0
if [ $? -ne 0 ]; then
  echo "Error setting nic1 to hostonlyadapter - exiting."
  exit 255
fi

# boot up the VM
vboxmanage startvm ${vmname} --type headless
if [ $? -ne 0 ]; then
  echo "Could not start ${vmname} -- exiting."
  exit 255
fi

# get the MAC address of this VM
macaddress=$(grep MACAddress ${HOME}/"VirtualBox VMs"/${vmname}/${vmname}.vbox | awk '{ print $4 }' | cut -d \" -f 2)

# change the format to include :
macformatted="${macaddress:0:2}:${macaddress:2:2}:${macaddress:4:2}:${macaddress:6:2}:${macaddress:8:2}:${macaddress:10:2}"

# lowercase - not necessary on OSX
# realmac=$(echo $macformatted | tr [:upper:] [:lower:])

# find the IP of the machine using NMAP + the MAC address
macfindattempt=0
macfindattemptmax=60 # we wait up to 2 minutes for the VM to boot up
while [ ${macfindattempt} -lt ${macfindattemptmax} ]; do
  let macfindattempt+=1
  if [ ${macfindattempt} -gt ${macfindattemptmax} ]; then
    echo "Max attempts reached -- exiting!"
    exit 255
  fi

  # grep -q dnsmasq.*DHCPACK.*${realmac} /var/log/messages
  sudo nmap -Pn -p 22 10.187.88.0/24 --open | grep -B5 "MAC Address: ${macformatted}" | grep -q 'scan report'
  if [ $? -eq 0 ]; then
    # ipaddr=$(grep dnsmasq.*DHCPACK.*${realmac} /var/log/messages | awk '{ print $7 }')
    ipaddr=$(sudo nmap -Pn -p 22 10.187.88.0/24 --open | grep -B5 "MAC Address: ${macformatted}" | grep 'scan report' | awk '{ print $5 }')
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
sshpass -p ${sshpasswd} scp ${sshopts} ${HOME}/git/github/scripts/bash/setup_vbox_minion.sh root@${ipaddr}:/tmp
if [ $? -ne 0 ]; then
  echo "Error copying /storage/vbox/ova/setup_minion.sh to ${ipaddr} -- exiting!"
  exit 255
fi

# execute the script
sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} bash /tmp/setup_vbox_minion.sh ${vmname}
if [ $? -ne 0 ]; then
  echo "Error configuring minion at ${ipaddr} -- exiting!"
  exit 255
fi

# remove the script
# sshpass -p ${sshpasswd} ssh ${sshopts} root@${ipaddr} rm /tmp/setup_vbox_minion.sh

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