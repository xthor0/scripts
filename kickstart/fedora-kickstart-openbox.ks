############
# TODO
############

# LXDM - there has to be a way in the post section to set openbox to be the default session
# post section problems - brave-browser isn't installing, and the virtualbox modules don't seem to be installing either
# also none of the dotfiles and fonts are installing...

# Remaster the server ISO so that it loads the kickstart file right from disk...

# Configure installation method
install
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-31&arch=x86_64"
repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f31&arch=x86_64" --cost=0
repo --name=rpmfusion-free --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-31&arch=x86_64" --includepkgs=rpmfusion-free-release
repo --name=rpmfusion-free-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-31&arch=x86_64" --cost=0
repo --name=rpmfusion-nonfree --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-31&arch=x86_64" --includepkgs=rpmfusion-nonfree-release
repo --name=rpmfusion-nonfree-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-31&arch=x86_64" --cost=0

# zerombr
zerombr

# Configure Boot Loader
bootloader --location=mbr --driveorder=sda

# Create Physical Partition
# this will need adjustments when I use it on a physical machine
part /boot --size=512 --asprimary --ondrive=sda --fstype=xfs
part swap --size=2048 --ondrive=sda
part / --size=8192 --grow --asprimary --ondrive=sda --fstype=xfs

# Remove all existing partitions
clearpart --all --drives=sda

# Configure Firewall
firewall --enabled --ssh

# Configure Network Interfaces
network --onboot=yes --bootproto=dhcp --hostname=fedcrunch-test

# Configure Keyboard Layouts
keyboard us

# Configure Language During Installation
lang en_US

# Configure X Window System
xconfig --startxonboot

# Configure Time Zone
timezone US/Denver

# lock root user
rootpw --lock

# Create User Account
user --groups=wheel --name=xthor --password=$6$HWYbWvgmz8oOzpsm$F5uqEwOaA2QUgtpsgvnQoIOJCrL7gz42RkghGZivxAR37FCQfaFvRfuGDW5cj3R2KQgpNAdqD7GyD0J5dLoob0 --iscrypted --gecos="Ben Brown"

# Perform Installation in Text Mode
text

# Package Selection
%packages
@core
@standard
@hardware-support
@base-x
@fonts
@libreoffice
@multimedia
@networkmanager-submodules
@printing
vim-enhanced
nmap
vim-X11
lynx
axel
freerdp
terminator
expect
ncdu
pwgen
vlc
kernel-devel
telegram-desktop
fuse-exfat
htop
remmina-plugins-rdp
arc-theme
htop
exfat-utils
git
putty
gimp
hexedit
flatpak
f3
screen
p7zip-plugins
iperf
tint2
Thunar
xfce4-notifyd
tlp
x11-ssh-askpass
heisenbug-backgrounds-base
openbox
obconf
compton
volumeicon
nitrogen
conky
xscreensaver
lxqt-openssh-askpass
xfce4-power-manager
blueman
arandr
leafpad
lxappearance
network-manager-applet
xbacklight
flameshot
playerctl
mate-calc
elfutils-libelf-devel
podman-docker
tlp
lxdm
lxterminal
%end

# Post-installation Script
%post
# install rpmfusion release packages
dnf -y install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-31.noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-31.noarch.rpm

# better fonts!
dnf -y copr enable dawid/better_fonts
dnf -y install fontconfig-enhanced-defaults fontconfig-font-replacements

# install vscode
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
dnf -y install code

# configure VirtualBox repo
curl http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo | tee /etc/yum.repos.d/virtualbox.repo

# brave browser
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
dnf -y install brave-browser

# configure VirtualBox packages
# if we're a VirtualBox guest, install these apps
lspci | grep -q 'InnoTek Systemberatung GmbH VirtualBox Guest Service'
if [ \$? -eq 0 ]; then
  echo "Running as a VM, adjusting configuration..."

  # let's kill xscreensaver, as there's really no reason to keep it running on a VM, we already have OS lock screens
  echo "Removing xscreensaver..."
  sudo dnf -y remove xscreensaver-base

  # the Fedora supplied virtualbox guest additions work great - except, shared folders do not work
  echo "Installing akmod-VirtualBox..."
  sudo dnf -y install akmod-VirtualBox
  retval=\$?
else
  # if we're bare metal, install VirtualBox hypervisor
  echo "Installing VirtualBox-6.0..."
  sudo dnf -y install VirtualBox-6.0
  retval=\$?
fi
if [ \${retval} -ne 0 ]; then
  echo "Error installing packages - review output above. Exiting."
  exit 255
fi

# if we're running an Intel video chipset, we need to tweak a file so that tearing is reduced drastically
cat << EOF | tee /etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
Identifier "Intel Graphics"
Driver "intel"
Option "AccelMethod" "sna"
Option "TearFree" "true"
EndSection
EOF
fi

# kill firewalld
sudo systemctl disable firewalld

# create dirs to hold fonts and temp files
mkdir /home/xthor/.fonts /home/xthor/tmp >& /dev/null
cd /home/xthor/tmp

# we need to copy in a shload of dotfiles... mostly for Openbox and Terminator, but... yeah.
# I need something sexier than curl | tar but... it's 12 AM :)
wget https://xw-killer-dotfiles.s3-us-west-1.amazonaws.com/killer_dotfiles.tgz && tar zxvf killer_dotfiles.tgz -C /home/xthor

# also - Terminus TTF. Download the zip and stuff the ttf files in ~/.fonts - otherwise, terminator
# will be ugly and unhappy
wget https://files.ax86.net/terminus-ttf/files/latest.zip
unzip latest.zip && mv terminus-ttf-*/*.ttf /home/xthor/.fonts

# cleanup
rm -rf terminus-ttf-* killer_dotfiles.tgz

# FIN
%end

# Reboot After Installation
reboot --eject