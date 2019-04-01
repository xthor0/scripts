# this is designed to be used as a virtualbox template

install
cdrom

# add in some repos
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/7/x86_64
repo --name=saltstack --baseurl=https://repo.saltstack.com/yum/redhat/7/x86_64/latest

# force text mode, please
text

# can we put network here? we may have to move it - if we don't do this the system boots without a NIC
#network --device=link --bootproto=dhcp
network  --bootproto=static --device=link --gateway=10.187.88.1 --ip=10.187.88.10 --nameserver=10.187.88.1 --netmask=255.255.255.0 --noipv6 --activate
network  --hostname=salt-master.lab

# System authorization information
auth --enableshadow --passalgo=sha512

# System language
lang en_US.UTF-8

# disable firstboot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# Disable firewall (We use hardware firewalls)
firewall --disabled

# Set SELinux to enforcing (Which is default)
selinux --enforcing

# Set the timezone
timezone America/Denver --isUtc

# We are the boot loader
bootloader --location=mbr --driveorder=sda

# Set the root password
rootpw p@ssw0rd

# disk configuration - designed to fit in default 8GB VDI that VBox creates :)
clearpart --drives=sda --all --initlabel
part /boot --fstype="ext4"  --ondisk=sda --size=512
part pv.2  --fstype="lvmpv" --ondisk=sda --size=1   --grow
volgroup vg0 --pesize=4096 pv.2
logvol /    --fstype="ext4" --name="root" --vgname="vg0" --size=4096 --grow

# Reboot after installation
reboot --eject

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
salt-master
salt-ssh
epel-release
# necessary for the freaking vbox guest additions
gcc
kernel-devel
kernel-headers
dkms
make
bzip2
p7zip-plugins
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

%post
# even though kickstart HAS a repo definition, it doesn't actually create the yum config files
rpm -ivh https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm

# add my ssh pubkey to this server
mkdir -m0700 /root/.ssh/

cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf imported-openssh-key
EOF

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
restorecon -R /root/.ssh/

### firewall should be off. We can always turn it back on with Salt later.
systemctl disable firewalld

# back up /etc/rc.d/rc.local, 'cause we're gonna clobber it
cp /etc/rc.d/rc.local /tmp/rc.local.bkup

# script to install vbox guest additions
# dear Oracle, why do you make this so damn difficult?
cat > /etc/rc.d/rc.local << EOF
#!/bin/bash
exec < /dev/tty6 > /dev/tty6
chvt 6

echo "Installing VirtualBox guest additions, please wait..." > /dev/console

# figure out what the latest version available is
vb_latest=\$(curl https://download.virtualbox.org/virtualbox/LATEST.TXT)

# download the ISO
wget -q https://download.virtualbox.org/virtualbox/\${vb_latest}/VBoxGuestAdditions_\${vb_latest}.iso -O /tmp/vbox_guest_addt.iso
if [ \$? -ne 0 ]; then
  echo "Unable to download VirtualBox Guest ISO. Exiting." > /dev/console
  read -p "Press Enter to continue." enterkey
  chvt 1
  exit 255
fi

# make a temp directory
mkdir /tmp/vbg && cd /tmp/vbg

# extract the ISO
7z x /tmp/vbox_guest_addt.iso

# run the installer
if [ -f VBoxLinuxAdditions.run ]; then
  chmod u+x VBoxLinuxAdditions.run
  ./VBoxLinuxAdditions.run
else
  echo "Error - cannot find VBoxLinuxAdditions.run. Exiting." > /dev/console
  read -p "Press Enter to continue." enterkey
  chvt 1
  exit 255
fi

# let's clean up this mess
rm -rf /tmp/vbg /tmp/vbox_guest_addt.iso
cat /tmp/rc.local.bkup | tee /etc/rc.local
chvt 1

EOF

# create salt master config file
cat > /etc/salt/master << EOF
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

EOF

# create reactor directory
mkdir -p /srv/salt/reactor

# create reactor to auto accept key
cat > /srv/salt/reactor/auto_accept_key.sls << EOF
reactor__cloud_created__master_add_minion:
  wheel.key.accept:
    - match: {{ data['id'] }}
EOF

# make salt-master run at boot
systemctl enable salt-master

# Make sure new rc.local is also executable
chmod 755 /etc/rc.d/rc.local

# End of kickstart script
%end