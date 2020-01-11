# Configure installation method
install
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-31&arch=x86_64"
repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f31&arch=x86_64" --cost=0

# Configure Firewall
firewall --disabled

# Configure Network Interfaces
# network --onboot=yes --bootproto=dhcp --hostname=fedcrunch

# Configure Keyboard Layouts
keyboard us

# Configure Language During Installation
lang en_US

# Configure X Window System
xconfig --startxonboot

# Configure Time Zone
timezone America/Denver

# lock root user
rootpw --lock

# add a user, with root, that will be deleted by Ansible
user --groups=wheel --name=ansibleprep --password=p@ssw0rd --uid=9999 --gid=9999

# ansible creates user accounts, so we don't need firstboot
firstboot --disable

# launch graphical install - makes network selection and disk partitioning easier
# graphical
text

## TODO: encryption!
# my thoughts are: set a default password, and then make the user change it first thing
# luks can remove the old password

# automatically decide what disk to partition and how to use it
%pre
ROOTDRIVE=""
for DEV in vda sda nvme0n1; do
  if [ -d /sys/block/${DEV} ]; then
    if [ $(cat /sys/block/${DEV}/removable) -eq 0 ]; then
      if [ -z ${ROOTDRIVE} ]; then
        ROOTDRIVE=${DEV}
        SIZE=$(cat /sys/block/${DEV}/size)
        SIZEGB=$((${SIZE}/2**21))
      fi
    fi
  fi
done


chassistype=$(hostnamectl status | grep Chassis | awk '{ print $2 }')
if [ "${chassistype}" == "vm" ]; then
  swapsetup="--size=1024"
elif [ "${chassistype}" == "laptop" ]; then
  swapsetup="--hibernation"
else
  swapsetup="--recommended"
fi

MEMTOTAL=$(grep ^MemTotal /proc/meminfo | awk '{ print $2 }')
MEMGB=$(expr ${MEMTOTAL} / 1024 / 1024)

if [ ${MEMGB} -ge 8 ]; then
  SWAP=8
else
  SWAP=$(expr ${MEMGB} / 2)
fi

if [ ${SIZEGB} -le 50 ]; then
  cat << EOF > /tmp/part-include
clearpart --all --drives=$ROOTDRIVE --initlabel
ignoredisk --only-use=$ROOTDRIVE
part /boot/efi --fstype=efi --grow --maxsize=200 --size=20
part /boot --fstype=xfs --ondisk=$ROOTDRIVE --size=1000
part pv.2 --ondisk=$ROOTDRIVE --size=1 --grow
volgroup vg0 pv.2
logvol swap  --fstype="swap" ${swapsetup} --name=lv_swap --vgname=vg0
logvol /  --fstype="xfs" --size=5 --name=root --vgname=vg0 --grow
EOF
else
  cat << EOF > /tmp/part-include
clearpart --all --drives=$ROOTDRIVE --initlabel
ignoredisk --only-use=$ROOTDRIVE
part /boot/efi --fstype=efi --grow --maxsize=200 --size=20
part /boot --fstype=xfs --ondisk=$ROOTDRIVE --size=1000
part pv.2 --fstype=lvmpv --ondisk=$ROOTDRIVE --size=1 --grow --encrypted --backuppassphrase
volgroup vg0 --pesize=4096 pv.2
logvol swap  --fstype="swap" ${swapsetup} --name=lv_swap --vgname=vg0
logvol /  --fstype="xfs" --size=51200 --name=root --vgname=vg0
logvol /home  --fstype="xfs" --size=5 --name=home --vgname=vg0 --grow
EOF
fi
%end

# include for disk partitioning - stolen from https://www.redhat.com/archives/kickstart-list/2012-October/msg00014.html
%include /tmp/part-include

# Package Selection
%packages
@core
@standard
@hardware-support
@base-x
@fonts
@networkmanager-submodules
openbox
ansible
lxterminal
lightdm-gtk
tint2
network-manager-applet
%end

# Post-installation Script
%post

mkdir -p /home/ansibleprep/.config/openbox
cat << EOF > /home/ansibleprep/.config/openbox/autostart
#!/bin/bash

tint2 &
nm-applet &

lxterminal -e "echo this is where ansible-playbook would run && read -n1 -s -r -p \"Press any key to continue. \""
EOF

# make lightdm auto-login once
cat << EOF > /etc/lightdm/lightdm.conf.d/88-ansible-autologin.conf
[SeatDefaults]
autologin-user=ansibleprep
autologin-user-timeout=0
user-session=openbox-session
EOF

chown -R ansibleprep:ansibleprep /home/ansibleprep/.config 
chmod 700 /home/ansibleprep/.config/openbox/autostart

# FIN
%end

# Reboot After Installation
reboot
