# Configure installation method
install
url --url=http://buibui.xthorsworld.com/mirror/fedora/31/x86_64/os/
# DO NOT DO NOT ENABLE THIS! on F31, pulling in updates during installation broke wifi permanently!
repo --name=fedora-updates --baseurl=http://buibui.xthorsworld.com/mirror/fedora/31/x86_64/updates/ --cost=0
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
lightdm-gtk
lxterminal
xfce4-appfinder
xss-lock
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
gcc
make
perl
numix-icon-theme
pcmanfm
dunst
plymouth-theme-hot-dog
ansible
jq
golang
python3-boto
bridge-utils
libvirt
virt-install
qemu-kvm
libguestfs-tools-c
virt-viewer
%end

# Post-installation Script
#exec < /dev/tty3 > /dev/tty3
%post --logfile=/root/kickstart-post.log

## ENABLE DNF REPOS FOR SOFTWARE I (MIGHT) INSTALL
# install rpmfusion release packages

echo "Enabling rpmfusion repository"
dnf -y install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-31.noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-31.noarch.rpm
echo "Done."

echo "Enabling better_fonts repository"
# make sure better_fonts copr is enabled 
dnf -y copr enable dawid/better_fonts
echo "Done."

# vscode
echo "Enabling vscode repository"
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
echo "Done."

# brave browser
echo "Enabling Brave repository"
dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
echo "Done."

# chrome
echo "Enabling Chrome repository"
cat << EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF
echo "Done."

# spotify
echo "Enabling Spotify repository"
dnf config-manager --add-repo=https://negativo17.org/repos/fedora-spotify.repo
echo "Done."

# pritunl
echo "Enabling pritunl repository"
sudo tee /etc/yum.repos.d/pritunl.repo << EOF
[pritunl]
name=Pritunl Stable Repository
baseurl=https://repo.pritunl.com/stable/yum/fedora/30/
gpgcheck=1
enabled=1
EOF

gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A
gpg --armor --export 7568D9BB55FF9E5287D586017AE645C0CF8E292A > key.tmp; sudo rpm --import key.tmp; rm -f key.tmp
echo "Done."

# kubectl
echo "Enabling kubernetes repository"
cat << EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
echo "Done."

# slack
echo "Enabling slack repo and installing Slack..."
dnf -y copr enable jdoss/slack-repo && dnf -y install slack-repo && dnf -y install slack
echo "Done."

# set the hot dog plymouth theme because it's cooler (and doesn't suffer from the stupid monitor bug)
plymouth-set-default-theme hot-dog -R

# install stuff that doesn't come from yum
echo "Installing Keybase..."
dnf -y install https://prerelease.keybase.io/keybase_amd64.rpm
echo "Done."

echo "Installing Zoom..."
dnf -y install https://zoom.us/client/latest/zoom_x86_64.rpm
echo "Done."

# install a bunch of packages from the repos we just set up
echo "Installing packages..."
dnf -y install pritunl-client-electron spotify-client kubectl brave-browser google-chrome-stable awscli
echo "Done."

## SET UP SKEL FILES
mkdir -p /etc/skel/tmp

# grab everything from Ben's github dotfiles repo and install the files
curl -L https://api.github.com/repos/xthor0/dotfiles/tarball/nav > /tmp/dotfiles.tgz
if [ $? -eq 0 ]; then
  cd /tmp && tar xf dotfiles.tgz && cd xthor0-dotfiles* && rsync -a . /etc/skel/
  if [ $? -eq 0 ]; then
    # clean up
    cd ..
    rm -rf dotfiles.tgz xthor0-dotfiles*
  fi
fi

# get chassis type
chassistype=$(hostnamectl status | grep Chassis | awk '{ print $2 }')

# set up SSH if we're a desktop, TLP if we're a laptop 
if [ "$chassistype" == "laptop" ]; then
  systemctl enable tlp
else
  systemctl enable sshd && systemctl start sshd
fi

# FIN
%end

# Reboot After Installation
# commented 'cause this doesn't effing work and on my Chromebook, it just hangs. Stupid.
reboot --eject
