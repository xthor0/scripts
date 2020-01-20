# Configure installation method
install
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-31&arch=x86_64"
# why does this break wifi?
# repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f31&arch=x86_64" --cost=0

# Configure Firewall
firewall --disabled

# Configure Network Interfaces
network --onboot=yes --bootproto=dhcp --hostname=fedcrunch

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

# this user has root privs and should have the password changed on first boot
user --groups=wheel --name=xthor --password=p@ssw0rd

# ansible creates user accounts, so we don't need firstboot
firstboot --disable

# launch graphical install - makes network selection and disk partitioning easier
# graphical
text

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

cat << EOF > /tmp/part-include
clearpart --all --drives=$ROOTDRIVE --initlabel
ignoredisk --only-use=$ROOTDRIVE
EOF

if [ -d /sys/firmware/efi ]; then
  echo "part /boot/efi --fstype=efi --size=1024" >> /tmp/part-include
fi

cat << EOF | tee -a /tmp/part-include
part /boot --fstype=xfs --ondisk=$ROOTDRIVE --size=1000
part pv.3 --fstype=lvmpv --ondisk=$ROOTDRIVE --size=1 --grow
volgroup vg0 pv.3
logvol swap  --fstype="swap" ${swapsetup} --name=lv_swap --vgname=vg0
EOF

if [ "${chassistype}" != "vm" ]; then
  echo "logvol /  --fstype=xfs --size=5 --name=root --vgname=vg0 --grow --encrypted" >> /tmp/part-include
else
  echo "logvol /  --fstype=xfs --size=5 --name=root --vgname=vg0 --grow" >> /tmp/part-include
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

mkdir -p /home/xthor/.config/openbox
cat << EOF > /home/xthor/.config/openbox/autostart
#!/bin/bash

tint2 &
nm-applet &

lxterminal -e "echo this is where ansible-playbook would run && read -n1 -s -r -p \"Press any key to continue. \""
EOF

# make lightdm auto-login once
cat << EOF > /etc/lightdm/lightdm.conf.d/88-xthor-autologin.conf
# this should be removed by ansible after configuration!
[Seat:*]
autologin-user=xthor
autologin-user-timeout=0
user-session=openbox
EOF

chown -R xthor:xthor /home/xthor/.config 
chmod 700 /home/xthor/.config/openbox/autostart

# FIN
%end

# Reboot After Installation
reboot
