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
graphical

# TODO:
# 1 - make openbox the default session for LXDM. (Or, find an LXDM alternative.)
# 2 - make ansibleprep auto-login so that the initial script runs automatically.
# 3 - figure out how to auto partition the drive, and even find the right drive (nvme0n1 vs sda, for example).

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
lxdm
%end

# Post-installation Script
#%post --erroronfail
#exec < /dev/tty3 > /dev/tty3
#chvt 3
%post

mkdir -p /home/ansibleprep/.config/openbox
cat << EOF > /home/ansibleprep/.config/openbox/autostart
#!/bin/bash

lxterminal -c "echo this is where ansible-playbook would run && read -n1 -s -r -p \"Press any key to continue. \""
EOF

chown -R ansibleprep:ansibleprep /home/ansibleprep/.config
chmod 700 /home/ansibleprep/.config/openbox/autostart

# FIN
%end

# Reboot After Installation
reboot
