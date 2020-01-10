# Configure installation method
install
url --url=http://buibui.xthorsworld.com/mirror/fedora/31/x86_64/os/
# DO NOT DO NOT ENABLE THIS! on F31, pulling in updates during installation broke wifi permanently!
# repo --name=fedora-updates --baseurl=http://buibui.xthorsworld.com/mirror/fedora/31/x86_64/updates/ --cost=0
repo --name=rpmfusion-free --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-31&arch=x86_64" --includepkgs=rpmfusion-free-release
repo --name=rpmfusion-free-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-31&arch=x86_64" --cost=0
repo --name=rpmfusion-nonfree --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-31&arch=x86_64" --includepkgs=rpmfusion-nonfree-release
repo --name=rpmfusion-nonfree-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-31&arch=x86_64" --cost=0
repo --name=better-fonts-copr --baseurl=https://copr-be.cloud.fedoraproject.org/results/dawid/better_fonts/fedora-31-x86_64/

# to use internet mirrors replace the url and fedora-updates repo with these:
# url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-31&arch=x86_64"
# repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f31&arch=x86_64" --cost=0

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

# user accounts cannot be created during installation and MUST be created using firstboot
# otherwise - .skel files don't work!
firstboot --enable

# launch graphical install - makes network selection and disk partitioning easier
graphical

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
lxqt-openssh-askpass
xfce4-power-manager
blueberry
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
lxterminal
initial-setup-gui
fontconfig-enhanced-defaults
fontconfig-font-replacements
NetworkManager-openvpn-gnome
gvfs-smb
sox
libreoffice
mupdf
virtualbox-guest-additions
genisoimage
gcc
make
perl
numix-icon-theme
pcmanfm
firefox
lightdm-gtk
dunst
light-locker
plymouth-theme-hot-dog
ansible
bridge-utils
libvirt
virt-install
qemu-kvm
libguestfs-tools-c
virt-viewer
python3-boto
%end

# Post-installation Script
#%post --erroronfail
#exec < /dev/tty3 > /dev/tty3
#chvt 3
%post --log=/root/kickstart-post.log

# install nvidia drivers (this won't work outside of post)
#dnf -y install akmod-nvidia
### NOTE ABOUT NVIDIA DRIVERS
# the nvidia drivers from rpmfusion compile a driver IMMEDIATELY after installation
# and it happens in the background - so, unless I hard-code a sleep or something, the
# drivers aren't gonna work on reboot.

### dnf/yum repo config
# set up chrome repo
cat << EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF

# install rpmfusion release packages
dnf -y install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-31.noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-31.noarch.rpm

# make sure better_fonts copr is enabled 
dnf -y copr enable dawid/better_fonts

# brave browser
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

# spotify client
dnf config-manager --add-repo=https://negativo17.org/repos/fedora-spotify.repo

# vscode
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

# pritunl
tee /etc/yum.repos.d/pritunl.repo << EOF
[pritunl]
name=Pritunl Stable Repository
baseurl=https://repo.pritunl.com/stable/yum/fedora/30/
gpgcheck=1
enabled=1
EOF

gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A
gpg --armor --export 7568D9BB55FF9E5287D586017AE645C0CF8E292A > key.tmp; sudo rpm --import key.tmp; rm -f key.tmp

# slack
dnf -y copr enable jdoss/slack-repo && dnf -y install slack-repo

# kubectl
cat << EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

### end dnf/yum repo configs

# set hotdog plymouth theme
plymouth-set-default-theme hot-dog -R

# install packages
sudo dnf -y install awscli slack spotify-client google-chrome-stable

### begin modify skel files

echo "Setting up .skel files..."
# without this, slim won't launch openbox
cat << EOF > /etc/skel/.xinitrc
#!/bin/bash
exec openbox-session
EOF
chmod 700 /etc/skel/.xinitrc

# set up skel files to run 
mkdir -p /etc/skel/.config/openbox 

cat << EOF > /etc/skel/.config/openbox/autostart
# this should be deleted by .fedcrunch-setup 
/usr/lib64/xfce4/notifyd/xfce4-notifyd &
nm-applet &
tint2 &
lxterminal -e \${HOME}/.fedcrunch-setup 
EOF
chmod 700 /etc/skel/.config/openbox/autostart

cat << EOF > /etc/skel/.fedcrunch-setup
#!/bin/bash

## TODO: Make this more interactive!

echo "Welcome to the FedCruch setup script!"
echo
echo "I'm ready when you are, but make sure you can give this your full attention."
echo "sudo times out - and you may have to re-enter your password a few times."
read -n1 -s -r -p "Press any key to continue. "
echo

# upgrade all packages
sudo dnf -y upgrade
if [ \$? -ne 0 ]; then
  echo "Error updating the system. Take a look at the error before proceeding."
  read -n1 -s -r -p "Press any key to continue. "
fi

echo "Installing fonts and preferred dotfiles..."

# create directories
mkdir \${HOME}/tmp >& /dev/null
pushd \${HOME}/tmp
if [ \$? -ne 0 ]; then
  echo "Can't cd to \${HOME}/tmp"
  read -n1 -s -r -p "Press any key to exit."
  exit 255
fi

# grab everything from Ben's github dotfiles repo and install the files
echo "Installing dotfiles from https://github.com/xthor0/dotfiles.git -- please wait!"
# remove /nav to get master branch (but after merge)
curl -LO https://api.github.com/repos/xthor0/dotfiles/tarball/nav
if [ \$? -eq 0 ]; then
  tar xf tarball && cd xthor0-dotfiles* && rsync -a . \${HOME}
  if [ \$? -eq 0 ]; then
    # clean up
    rm -rf tarball xthor0-dotfiles*
  else
    echo "Error installing dotfiles."
    read -n1 -s -r -p "Press any key to continue. "
  fi
else
  echo "Error downloading from api.github.com."
  read -n1 -s -r -p "Press any key to continue. "
fi
popd

# get chassis type
chassistype=\$(hostnamectl status | grep Chassis | awk '{ print \$2 }')

# set up SSH if we're a desktop, TLP if we're a laptop 
if [ "\$chassistype" == "laptop" ]; then
  echo "Enabling tlp at boot..."
  sudo systemctl enable tlp
else
  echo "Enabling sshd..."
  sudo systemctl enable sshd && sudo systemctl start sshd
fi

echo "Install Zoom?"
read -p "(Y/N): " -n1 -r
if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
  sudo dnf -y install https://zoom.us/client/latest/zoom_x86_64.rpm
fi

echo "Install Keybase?"
read -p "(Y/N): " -n1 -r
if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
  sudo dnf -y install https://prerelease.keybase.io/keybase_amd64.rpm
fi

echo "Install Pritunl client?"
read -p "(Y/N): " -n1 -r
if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
  sudo dnf -y install pritunl-client-electron
fi

read -n1 -s -r -p "Press any key to reboot!"
sudo reboot
EOF
chmod 700 /etc/skel/.fedcrunch-setup

### end modify skel files

#chvt 1

# FIN
%end

# Reboot After Installation
# commented 'cause this doesn't effing work and on my Chromebook, it just hangs. Stupid.
reboot --eject
