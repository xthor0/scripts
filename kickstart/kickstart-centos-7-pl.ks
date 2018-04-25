# built for CentOS 7 on VMware

# Use CDROM installation media
install
cdrom

# text mode, please!
text

# Accept EULA
eula --agreed

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System authorization information
auth --enableshadow --passalgo=sha512

# System language
lang en_US.UTF-8

# SELinux
selinux --enforcing

# Network information - if we don't use 'device=link' we may not have network at the end of this script
network --onboot yes --device=link --bootproto=dhcp --noipv6 --activate

# hostname will be set by salt-cloud
network --hostname centos-7-template

# Root password, should be reset in this kickstart tho
rootpw p@ssw0rd

# System timezone
timezone America/Denver --isUtc

# System bootloader configuration
bootloader --location=mbr --boot-drive=sda

# Partition clearing information
clearpart --all --drives=sda
ignoredisk --only-use=sda

# LVM Disk partitioning information - make sure the template has 16GB and grow /home to fill
part /boot --fstype="ext4" --ondisk=sda --size=1000
part pv.2  --fstype="lvmpv" --ondisk=sda --size=1 --grow
volgroup vg0 --pesize=4096 pv.2
logvol /  --fstype="xfs" --size=5000 --name=root --vgname=vg0
logvol /home  --fstype="xfs" --size=5000 --name=home --vgname=vg0
logvol /tmp  --fstype="xfs" --size=500 --name=tmp --vgname=vg0
logvol /var  --fstype="xfs" --size=3500 --name=var --vgname=vg0
logvol /var/tmp  --fstype="xfs" --size=500 --name=var_tmp --vgname=vg0
logvol /var/log  --fstype="xfs" --size=1500 --name=var_log --vgname=vg0
logvol /var/log/audit  --fstype="xfs" --size=500 --name=var_log_audit --vgname=vg0
logvol /opt  --fstype="xfs" --size=1000 --name=opt --vgname=vg0
logvol /var/www  --fstype="xfs" --size=1000 --name=var_www --vgname=vg0
logvol swap  --fstype="swap" --size=500 --name=lv_swap --vgname=vg0

# reboot after installation, por favor
reboot --eject

%packages
@core --nodefaults
rsync
curl
epel-release
screen
vim-enhanced
bash-completion
perl
open-vm-tools
# we don't need the following packages installed
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

# End of kickstart script
%end

