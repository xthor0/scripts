# Configure installation method
install
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-31&arch=x86_64"
repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f31&arch=x86_64" --cost=0
repo --name=rpmfusion-free --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-31&arch=x86_64" --includepkgs=rpmfusion-free-release
repo --name=rpmfusion-free-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-31&arch=x86_64" --cost=0
repo --name=rpmfusion-nonfree --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-31&arch=x86_64" --includepkgs=rpmfusion-nonfree-release
repo --name=rpmfusion-nonfree-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-31&arch=x86_64" --cost=0
repo --name=better-fonts-copr --baseurl=https://copr-be.cloud.fedoraproject.org/results/dawid/better_fonts/fedora-31-x86_64/

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
lxdm
lxterminal
xautolock
i3lock
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
awscli
%end

# Post-installation Script
#%post --erroronfail
#exec < /dev/tty3 > /dev/tty3
#chvt 3
%post

# install rpmfusion release packages
dnf -y install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-31.noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-31.noarch.rpm

# make sure better_fonts copr is enabled 
dnf -y copr enable dawid/better_fonts

# install vscode repo
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

# configure VirtualBox repo
curl http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo > /etc/yum.repos.d/virtualbox.repo

# brave browser
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

# set up LXDM
sed -i 's/^# session=\/usr\/bin\/startlxde/session=\/bin\/openbox-session/g' /etc/lxdm/lxdm.conf

echo "Setting up .skel files..."
# set up skel files to run 
mkdir -p /etc/skel/.config/openbox 

cat << EOF > /etc/skel/.config/openbox/autostart
# this should be deleted by .fedcrunch-setup 
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

echo "Installing Slack from flathub..."

# install Slack from flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub com.slack.Slack
if [ \$? -ne 0 ]; then
  read -n1 -s -r -p "Flatpak configuration failed, consult the error message above and press a key to continue."
fi

# install brave and vscode
echo "Installing Brave browser, and vscode..."
sudo dnf -y install brave-browser code

echo "Upgrading all packages with dnf..."

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
curl -LO https://api.github.com/repos/xthor0/dotfiles/tarball
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
chassistype=$(hostnamectl status | grep Chassis | awk '{ print $2 }')

# set up SSH if we're a desktop, TLP if we're a laptop 
if [ "$chassistype" == "laptop" ]; then
  echo "Enabling tlp at boot..."
  sudo systemctl enable tlp
else
  echo "Enabling sshd..."
  sudo systemctl enable sshd && sudo systemctl start sshd
fi

# if we're a VirtualBox guest, install these apps
if [ "\${chassistype}" == "vm" ]; then
  echo "Running as a VM, adjusting configuration..."

  # no need to automatically lock the screen on a VM, we already have OS lock screens
  echo "Removing xautolock..."
  sed -i 's/^exec xautolock/\#exec xautolock/g' \${HOME}/.config/openbox/autostart

  # virtualbox needs you to be a member of vboxsf if you want to use shared folders from the host
  echo "Adding \$(whoami) to vboxsf group..."
  sudo usermod -aG vboxsf \$(whoami)
  retval=\$?
else
  # if we're bare metal, install VirtualBox hypervisor
  echo "Installing VirtualBox-6.0..."
  curl https://raw.githubusercontent.com/gryf/vboxmanage-bash-completion/master/VBoxManage | tee -a \${HOME}/.bash_completion >& /dev/null
  sudo dnf -y install VirtualBox-6.0
  retval=\$?
  
  # virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
  echo "Adding \$(whoami) to vboxusers group..."
  sudo usermod -aG vboxusers \$(whoami)
fi

# did it all go off without a hitch?
if [ \${retval} -ne 0 ]; then
  echo "Error installing packages - review output above. Exiting."
  exit 255
fi

read -n1 -s -r -p "Press any key to reboot!"
sudo reboot
EOF
chmod 700 /etc/skel/.fedcrunch-setup

chvt 1

# FIN
%end

# Reboot After Installation
reboot
