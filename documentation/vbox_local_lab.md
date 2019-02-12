# How to set up a local Salt lab with VirtualBox
This documentation will help you:
1. Host system that can serve as a NAT gateway for a local, private network segment
1. Virtualbox with a working Salt master
1. Minions that can be stood up and burned down for testing your Salt states and orchestration

# Configure host system
## Fedora 29
Configure IP forwarding as well as a NAT rule for your host-only network:
~~~
sudo sysctl net.ipv4.ip_forward=1
echo net.ipv4.ip_forward=1 | sudo tee /etc/sysctl.d/99-sysctl.conf
sudo iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{ print $5 }') -j MASQUERADE
~~~
Configure dnsmasq to provide DHCP and DNS for this network:
~~~
echo "domain=lab
interface=vboxnet0
dhcp-option=vboxnet0,6,10.187.88.1
dhcp-range=vboxnet0,10.187.88.100,10.187.88.250,2h
dhcp-option=vboxnet0,3,10.187.88.1
address=/salt-master/10.187.88.10
address=/salt/10.187.88.10" | sudo tee /etc/dnsmasq.d/vbox.conf
systemctl restart dnsmasq
systemctl enable dnsmasq
~~~
## OS X
All instructions can be found here: https://kfigiela.github.io/2014/11/07/using-native-os-x-nat-with-virutalbox/
Configure IP forwarding:
~~~
sudo sysctl net.inet.ip.forwarding=1
echo net.inet.ip.forwarding=1 | sudo tee -a /etc/sysctl.conf
~~~
Then, configure NAT for the virtualbox network by adding the following NAT rules to /etc/pf.conf after rdr-anchor line:
~~~
nat on {en0, en1} proto {tcp, udp, icmp} from 10.187.88.0/24 to any -> {en0, en1}
pass from {lo0, 10.187.88.0/24} to any keep state
~~~
Start the pf service:
~~~
sudo pfctl -e -f /etc/pf.conf
~~~
Install dnsmasq:
~~~
brew install dnsmasq
~~~
Configure dnsmasq:
~~~
echo "domain=lab
interface=vboxnet0
dhcp-option=vboxnet0,6,10.187.88.1
dhcp-range=vboxnet0,10.187.88.100,10.187.88.250,2h
dhcp-option=vboxnet0,3,10.187.88.1
address=/salt-master/10.187.88.10
address=/salt/10.187.88.10" | sudo tee -a /usr/local/etc/dnsmasq.conf
~~~
Start the service:
~~~
sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist
~~~
NOTE: This service probably won't start at boot, and I didn't dig enough to figure out why. Any time I used VPN, or rebooted, I had to re-run the pfctl command and the launchctl command again. 

## Optional: Bash completion for vboxmanage
https://github.com/gryf/vboxmanage-bash-completion/blob/master/VBoxManage

# SSH configuration on host system
Adding these lines to `$HOME/.ssh/config` will prevent your computer from adding anything in your lab to the `known_hosts` file on your computer.
~~~
Host salt-master.lab
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  User root
  LogLevel QUIET
  HostName 10.187.88.10

Host 10.187.88.*
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  User root
  LogLevel QUIET
~~~

# Install VirtualBox
I won't go into too much detail here - but if you're using a Linux distro, make sure you download the official builds from virtualbox.org instead of using whatever your distro supplies. All instructions assume you're using VirtualBox 6.0!

# VirtualBox network configuration
~~~
vboxmanage hostonlyif create
vboxmanage hostonlyif ipconfig vboxnet0 --ip 10.187.88.1 --netmask 255.255.255.0
~~~
The last few times I've set this up, DHCP has been enabled on the host-only network adapter <b>even though I explicitly turned it off.</b> I recommend launching the GUI and checking the host network configuration to make sure DHCP is <b>disabled</b>, and that you close and relaunch VirtualBox to be sure it is still disabled.

# Download a couple of ISO files
[This](https://www.dropbox.com/s/r8ncxp90omllj1c/vbox-salt-master-20190208.iso?dl=0) one will stand up a salt master for you.

And [this](https://www.dropbox.com/s/df7denul9gmaulw/vbox-template-20190208.iso?dl=0) one will build your CentOS template.

Download them both, the examples below assume they are in `~/Downloads`.

## build a salt master VM 
~~~
VBoxManage createvm --name salt-master --ostype RedHat_64 --register
VBoxManage modifyvm salt-master --memory 2048
vboxmanage modifyvm salt-master --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage createhd --filename ~/VirtualBox\ VMs/salt-master/salt-master.vdi --size 8000 --format VDI
VBoxManage storagectl salt-master --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach salt-master --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/salt-master/salt-master.vdi
VBoxManage storageattach salt-master --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/vbox-salt-master-20190208.iso
vboxmanage startvm salt-master
~~~
Once the VirtualBox window shows you sitting at a login prompt, do the following:
1. `ssh salt-master.lab` (the root password is `p@ssw0rd`)
1. make sure the `salt-master` process is running
1. make sure that the VirtualBox guest additions are installed: `VBoxControl -V`
1. copy your SSH key to root: `ssh-copy-id salt-master.lab`
1. shut it down, and then start it up in headless mode: `vboxmanage startvm salt-master --type headless`

## create the template VM 
~~~
VBoxManage createvm --name cent7template --ostype RedHat_64 --register
VBoxManage modifyvm cent7template --memory 1024
vboxmanage modifyvm cent7template --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage createhd --filename ~/VirtualBox\ VMs/cent7template/cent7template.vdi --size 8000 --format VDI
VBoxManage storagectl cent7template --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach cent7template --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/cent7template/cent7template.vdi
VBoxManage storageattach cent7template --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/vbox-template-20190208.iso
vboxmanage startvm cent7template
~~~
Once the VM is running, make sure you have an IP address supplied by dnsmasq and not VirtualBox. One easy way to tell - does your VM have a gateway? If not, DHCP is messed up and you need to disable it in VirtualBox.

You'll also want to copy your SSH key to the template, so you don't have to type the root password in again.

Then, shut down the VM.

# Test it
Clone the template, and spin up a new CentOS minion:
~~~
vboxmanage clonevm cent7template --name minion1 --register
vboxmanage guestproperty set minion1 GuestName minion1
vboxmanage startvm minion1 --type headless
~~~
If everything is working as expected, in a few seconds you should be able to run `salt \* test.ping` on your Salt master, and see a new minion named `minion1.lab` smiling back at you.

# Cleanup
When you're ready to remove a VM from your system, run the following commands.
From the salt master:
~~~
salt --async minion1.lab system.poweroff
salt-key -d minion1
~~~
From the host system:
~~~
vboxmanage unregistervm minion1 --delete
~~~

# Shared folders
I have VirtualBox configured to share the following directories with my Salt master:
* `$HOME/salt-dev/top` is mounted as `/srv/salt/top`
* `$HOME/salt-dev/pillar` is mounted as `/srv/salt/pillar`
* `$HOME/git/opssre/salt-states` is mounted as `/srv/salt/states` - that way, when I create a new feature branch and start developing a new state, my VM tracks that branch and I can simply commit my changes when development is complete.

Unfortunately, this will all need to be set up in the GUI if you want it to automount - because I haven't found a way to do this with `vboxmanage` from the command-line.