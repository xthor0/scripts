# End goal - make this all automated :)

## prep host system - in my case, Fedora 29
sudo sysctl net.ipv4.ip_forward=1
echo net.ipv4.ip_forward=1 | sudo tee /etc/sysctl.d/99-sysctl.conf
sudo iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{ print $5 }') -j MASQUERADE

## install virtualbox
I'll fill out the details here later

## virtualbox configuration
vboxmanage hostonlyif create
vboxmanage hostonlyif ipconfig vboxnet0 --ip 10.187.88.1 --netmask 255.255.255.0
<b>DHCP has been difficult to disable on the host-only adapter - might need to check this on next build</b>

## build a salt master VM 
~~~
VBoxManage createvm --name salt-master --ostype RedHat_64 --register
VBoxManage modifyvm salt-master --memory 2048
vboxmanage modifyvm salt-master --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage createhd --filename ~/VirtualBox\ VMs/salt-master/salt-master.vdi --size 8000 --format VDI
VBoxManage storagectl salt-master --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach salt-master --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/salt-master/salt-master.vdi
VBoxManage storagectl salt-master --name "IDE Controller" --add ide --controller PIIX4
VBoxManage storageattach salt-master --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/vbox-template-20190205.iso
vboxmanage startvm salt-master
~~~

## create the template VM 
~~~
VBoxManage createvm --name cent7template --ostype RedHat_64 --register
VBoxManage modifyvm cent7template --memory 1024
vboxmanage modifyvm cent7template --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage createhd --filename ~/VirtualBox\ VMs/cent7template/cent7template.vdi --size 8000 --format VDI
VBoxManage storagectl cent7template --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach cent7template --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/cent7template/cent7template.vdi
VBoxManage storagectl cent7template --name "IDE Controller" --add ide --controller PIIX4
VBoxManage storageattach cent7template --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/vbox-template-20190205.iso
vboxmanage startvm cent7template
~~~

## set up a shared directory in virtualbox like this:
$HOME/salt-dev, mounted to /srv on the guest - there doesn't seem to be a way to do this with vboxmanage

## contents of salt-master
~~~
file_roots:
  base:
    - /srv/salt/top
    - /srv/salt/states

pillar_roots:
  base:
    - /srv/salt/pillar

reactor:
  - 'salt/auth':
    - '/srv/salt/reactor/auto_accept_key.sls'

log_level: info
~~~

## contents of /srv/salt/reactor/auto_accept_key.sls:
~~~
reactor__cloud_created__master_add_minion:
  wheel.key.accept:
    - match: {{ data['id'] }}
~~~

## enable salt-master to run at startup and now
~~~
systemctl enable salt-master 
systemctl start salt-master 
~~~