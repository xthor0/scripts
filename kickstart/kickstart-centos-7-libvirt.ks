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
bootloader --location=mbr --boot-drive=vda

# Partition clearing information
clearpart --all --drives=vda
ignoredisk --only-use=vda

# LVM Disk partitioning information - make sure the template has 16GB and grow /home to fill
part /boot --fstype="ext4" --ondisk=vda --size=1000
part pv.2  --fstype="lvmpv" --ondisk=vda --size=1 --grow
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
# change to new vt and set stout/stdin
exec < /dev/tty6 > /dev/tty6
chvt 6

# change root password
passchange=0
while [ $passchange -eq 0 ]; do
        clear
        echo "[ Change the root password ]"
        echo
        echo "Please enter a new root password: "
        echo -n "#> "
        read -s rootpass
        echo "Now, enter it again: "
        echo -n "#> "
        read -s rootpass2
        if [ "$rootpass" == "$rootpass2" ]; then
                echo "Setting new root password..."
                echo $rootpass | passwd --stdin root
                if [ $? -eq 0 ]; then
                        echo "Root password set successfully."
                        passchange=1
                else
                        echo "Error changing password... let's try again."
                        sleep 5
                fi
        else
                echo "Root passwords don't match! Let's try again..."
                sleep 5
        fi
done

# set the hostname
retval=1
while [ $retval -eq 1 ]; do

        # get hostname information && set it
        clear
        echo "[ Hostname Configuration ]"
        echo
        echo "Please enter the hostname for this server."
        echo "This should be a fully-qualified hostname, i.e. hostname.sub.domain"
        echo
        echo -n "#> "
        read newhostname

        # confirm
        echo "The new hostname will be: $newhostname"
        echo "Is this correct? "
        echo
        echo -n " (Y/N) #> "
        read yesno_input
        yesno=$(echo $yesno_input | tr [:upper:] [:lower:])
        if [ "$yesno" != "y" ]; then
                continue
        fi

        # set the hostname with hostnamectl
        #hostnamectl set-hostname $newhostname
        #hostnamectl DOES NOT seem to work in the %post chroot
        echo $newhostname > /etc/hostname
        ## this sleep allows the weird message about starting hostnamectl to pass - otherwise you can't see the prompt for the IP address
        sleep 2

        # did the hostname get reset?
        grep -q localhost /etc/hostname
        if [ $? -eq 0 ]; then
                echo "Hostname not set! Re-running hostname config utility..."
                sleep 5
                continue
        else
                retval=0
        fi
done
## end set hostname

# install updates
echo "Checking for CentOS updates, please wait..."
# there will almost always be updates, but lets be efficient just in case...
yum -q -y check-update >& /dev/null
if [ $? -eq 100 ]; then
        echo "Installing CentOS updates, please wait..."
        yum -y upgrade
        if [ $? -eq 0 ]; then
                echo "Complete!"
        else
                echo "Error installing CentOS updates, please examine output!"
                read -n 1 -s -p "Press any key to continue..."
        fi
else
        echo "No CentOS updates to install."
fi

# change back to first vt
chvt 1

# End of kickstart script
%end

