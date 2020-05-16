# this is designed to be used as a virtualbox template

install
url --url http://mirror.xmission.com/centos/8/BaseOS/x86_64/os/

# force text mode, please
text

# network config
network --onboot yes --device=link --bootproto=dhcp --noipv6 --activate --hostname=kstestiso

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
#bootloader --location=partition

# Set the root password
rootpw --iscrypted $6$I36fz2ilA3$oGeh2bvotqgueURwKCIGEv5IGJxSrzxI0ujlprgjw5GODBaCcLWCA9.9OFcmM70XSd.HpoAzInqQrVwH7yZmK1

# add a user
user --name=xthor --groups=wheel --password=$6$buxo8MYolK$dFAc6t3ZT4vPLsD2RwA/awTKe49gEnrN/L7pZ4zMfOjPoICCXyMfqJuHv1H1aYVom2Rmpv6cBCmkVFwGjrd6o. --iscrypted

# Reboot after installation
reboot --eject

# partitioning depends on uefi/mbr config
%include /tmp/uefi
%include /tmp/legacy

clearpart --all --initlabel --drives=sda
%pre --logfile /tmp/kickstart.install.pre.log

if [ -d /sys/firmware/efi ] ; then

cat >> /tmp/uefi <<END

part /boot/efi --fstype=efi --size=512
part /boot --fstype="xfs"  --ondisk=sda --size=1024
part pv.01  --fstype="lvmpv" --ondisk=sda --size=1   --grow
volgroup vg0 --pesize=4096 pv.01
logvol swap --fstype="swap" --name="swap" --vgname="vg0" --size=128
logvol /    --fstype="ext4" --name="root" --vgname="vg0" --size=4096 --grow

END

else

cat >> /tmp/legacy <<END
 
bootloader --location=mbr --boot-drive=sda
part /boot --fstype="xfs"  --ondisk=sda --size=1024
part pv.01  --fstype="lvmpv" --ondisk=sda --size=1   --grow
volgroup vg0 --pesize=4096 pv.01
logvol swap --fstype="swap" --name="swap" --vgname="vg0" --size=128
logvol /    --fstype="ext4" --name="root" --vgname="vg0" --size=4096 --grow

END

fi 

if [ -d /sys/firmware/efi ] ; then
touch /tmp/legacy
else 
touch /tmp/uefi
fi
chvt 1

%end
%packages
@core --nodefaults
@^minimal-environment
vim-enhanced
bash-completion
wget
dnf-plugins-core
%end

%post
# add my ssh pubkey to this server
mkdir -m0700 /home/xthor/.ssh/

cat <<EOF >/home/xthor/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf imported-openssh-key
EOF

### set permissions
chmod 0600 /home/xthor/.ssh/authorized_keys

### set ownership
chown -R xthor:xthor /home/xthor/.ssh

### fix up selinux context
restorecon -R /home/xthor/.ssh/

### allow sudo without password
sed -i 's/^%wheel/\#%wheel/g' /etc/sudoers
sed -i 's/^\# %wheel/%wheel/g' /etc/sudoers

### why can't epel install from packages? Oh well
dnf config-manager --set-enabled PowerTools
dnf -y install epel-release

# End of kickstart script
%end
