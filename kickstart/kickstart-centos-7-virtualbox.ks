# built for CentOS 7 on VirtualBox

# Use CDROM installation media
install
#url --url=http://slc-prdinfrep01.stormwind.local/repos/centos/7/os/x86_64/
#url --url=http://mirror.facebook.net/centos/7/os/x86_64/
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
network --hostname vbox-guest

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
logvol /  --fstype="xfs" --size=4000 --name=root --vgname=vg0
logvol /home  --fstype="xfs" --size=1000 --name=home --vgname=vg0 --grow
logvol /tmp  --fstype="xfs" --size=500 --name=tmp --vgname=vg0
logvol /var  --fstype="xfs" --size=1000 --name=var --vgname=vg0
logvol swap  --fstype="swap" --size=500 --name=lv_swap --vgname=vg0

# reboot after installation, por favor
reboot --eject

%packages
@core --nodefaults
rsync
curl
epel-release
salt-repo-latest
salt-minion
screen
vim-enhanced
bash-completion
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
# fix fstab (security permissions)
sed -ie '/\/boot/ s/defaults/defaults,nosuid,noexec,nodev/' /etc/fstab

sleep 5

exec < /dev/tty6 > /dev/tty6 2> /dev/tty6
chvt 6

retval=1
while [ \$retval -eq 1 ]; do
        # get hostname information && set it
        clear
        echo "[ Hostname Configuration ]"
        echo
        echo "Please enter the hostname for this server."
        echo "This should be a fully-qualified hostname, i.e. hostname.sub.domain"
        echo
        read -p " #> " newhostname

        # confirm
        echo "The new hostname will be: \$newhostname"
        echo "Is this correct? "
        echo
        read -p " (Y/N) #> " yesno_input
        yesno=\$(echo \$yesno_input | tr [:upper:] [:lower:])
        if [ "\$yesno" != "y" ]; then
                continue
        fi

        # set the hostname with hostnamectl
        hostnamectl set-hostname \$newhostname
        ## this sleep allows the weird message about starting hostnamectl to pass 
	## otherwise you can't see the prompt for the IP address
        sleep 2

        # did the hostname get reset?
        grep -q localhost /etc/hostname
        if [ \$? -eq 0 ]; then
                echo "Hostname not set! Re-running hostname config utility..."
                sleep 5
                continue
        else
                retval=0
        fi
done
## end set hostname

## root password
retval=1
while [ \$retval -eq 1 ]; do
	echo "Please enter a password for 'root': "
	read -p "::> " root_password_1
	echo "Now, enter it again: "
	read -p "::> " root_password_2
	if [ "\$root_password_1" == "\$root_password_2" ]; then
		echo "Passwords match!"
		echo "\$root_password_1" | passwd --stdin root
		retval=\$?
	else
		echo "Passwords don't match!"
		read -n 1 -s -r -p "Press any key to continue..."
	fi
done

# back to main screen
chvt 1
exec < /dev/tty1 > /dev/tty1 2> /dev/tty1

# End of kickstart script
%end

