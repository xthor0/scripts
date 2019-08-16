# this is designed to be used as a virtualbox template

install
cdrom

# add in some repos
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/7/x86_64

# force text mode, please
text

# network config
network  --bootproto=static --device=enp0s8 --hostname=router.lab --ip=10.187.88.1 --netmask=255.255.255.0 --noipv6 --activate
network  --bootproto=dhcp --device=enp0s3 --noipv6 --activate

# System authorization information
auth --enableshadow --passalgo=sha512

# System language
lang en_US.UTF-8

# disable firstboot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# Set SELinux to enforcing (Which is default)
selinux --enforcing

# Set the timezone
timezone America/Denver --isUtc

# We are the boot loader
bootloader --location=mbr --driveorder=sda

# Set the root password
rootpw p@ssw0rd

# enable logging so we can see what happened
logging --level=debug

# disk configuration - designed to fit in default 8GB VDI that VBox creates :)
clearpart --drives=sda --all --initlabel
part /boot --fstype="ext4"  --ondisk=sda --size=512
part pv.2  --fstype="lvmpv" --ondisk=sda --size=1   --grow
volgroup vg0 --pesize=4096 pv.2
logvol /    --fstype="ext4" --name="root" --vgname="vg0" --size=4096 --grow

# Reboot after installation
reboot --eject

# enable firewalld service  
firewall --enable

%packages
@core --nodefaults
screen
vim-enhanced
policycoreutils-python
bash-completion
wget
rsync
deltarpm
yum-plugin-fastestmirror
epel-release
dnsmasq
bind-utils
tcpdump
lighttpd
# the below was stolen shamelessly from https://www.centos.org/forums/viewtopic.php?t=47262 (last post)
-aic94xx-firmware*
-alsa-*
-biosdevname
-btrfs-progs*
-dracut-network
-iprutils
-ivtv*
-iwl*firmware
-libertas*
-kexec-tools
-plymouth*
-postfix
-NetworkManager-wifi
%end

%post --log=/root/ks-post.log
# add my ssh pubkey to this server
mkdir -m0700 /root/.ssh/

cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor0-ssh-key
EOF

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
restorecon -R /root/.ssh/

### turn on dnsmasq
systemctl enable dnsmasq

### create config file for dnsmasq
cat << EOF > /etc/dnsmasq.d/lab.conf
domain=lab
dhcp-option=6,10.187.88.1
dhcp-range=10.187.88.20,10.187.88.250,2h
dhcp-option=3,10.187.88.1
no-resolv
host-record=salt-master,salt-master.lab,10.187.88.10
cname=salt.lab,salt-master.lab
server=8.8.8.8
EOF

# add a few firewall rules
# NOTE: regarding firewall-offline-cmd, the below commands SHOULD work
# unfortunately, they don't. I'm not the only one: https://serverfault.com/questions/838710/nmcli-is-not-working-in-kickstart-script
#firewall-offline-cmd --zone=trusted --change-interface=enp0s8
firewall-offline-cmd --zone=public --add-masquerade
echo 'ZONE=trusted' >> /etc/sysconfig/network-scripts/ifcfg-enp0s8
%end

# this allows the log file to persist a reboot... seriously, RedHat, this should be an option without the hack
%post --nochroot
cp /tmp/anaconda.log /mnt/sysimage/root/anaconda.log
%end 
