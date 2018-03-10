#!/bin/bash

# this script needs some work. At various points sudo privs could time out, and the user will be prompted again for a password
# we need to tell the user what we're doing at every step so that IF they are prompted, it isn't confusing as to why.

# we need sudo rights...
echo "This script requires sudo rights - let's check your permissions."
echo "Please enter your password (running: 'sudo whoami'): "
sudo whoami
if [ $? -ne 0 ]; then
	echo "Error - check your sudo permissions and/or password!"
	exit 255
fi

# add additional packages that don't come with Fedora by default
sudo su -c 'dnf install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'

# google fedora repo
cat << EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF

# virtualbox fedora repo
curl http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo | sudo tee /etc/yum.repos.d/virtualbox.repo

# improve fonts
sudo dnf copr enable dawid/better_fonts

# pycharm IDE for Python development
sudo dnf copr enable phracek/PyCharm 

# spotify
sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-spotify.repo

# do a full upgrade
sudo dnf -y upgrade

# install all the packages
sudo dnf -y install vim-enhanced nmap vim-X11 conky lynx axel freerdp terminator expect ncdu pwgen google-chrome-stable VirtualBox-5.2 vlc terminus-fonts-console terminus-fonts kernel-devel fontconfig-enhanced-defaults fontconfig-font-replacements pycharm-community spotify remmina-plugins-rdp arc-theme htop exfat-utils fuse-exfat nautilus-dropbox chrome-gnome-shell telegram-desktop git

# atom editor
# copr repo does not work with F27
#sudo dnf copr enable mosquito/atom
#wget https://atom.io/download/rpm -- maybe?

chassis=$(sudo dmidecode --string chassis-type)
if [ $chassis == "Notebook" ]; then
	# install tlp/powertop
	sudo dnf -y install tlp powertop

	# start powertop and tlp at boot
	sudo systemctl enable powertop
	sudo systemctl enable tlp
	sudo systemctl start powertop
	sudo systemctl start tlp
fi

if [ $chassis == "Desktop" ]; then
	# sshd if you've got a need
	sudo systemctl enable sshd
	sudo systemctl start sshd
fi

# nss-mdns is evil
sudo dnf -y remove nss-mdns

# TODO: modify this for Progleasing machines

# cypher cert from Active Directory
# wget --quiet --no-check-certificate --http-user=bebrow --ask-password 'https://cypher.pgx.local/certsrv/certnew.cer?ReqID=CACert&Renewal=0&Mode=inst&Enc=b64' -O cypher.crt
# cat cypher.crt | sudo tee /etc/pki/ca-trust/source/anchors/cypher.crt && sudo update-ca-trust && # rm cypher.crt

# telegram - this will extract to $HOME/Telegram
# cd $HOME && wget https://telegram.org/dl/desktop/linux -O - | tar Jxv 

# if we're running an Intel video chipset, we need to tweak a file so that tearing is reduced drastically
lspci | grep -qi VGA.*intel
if [ $? -eq 0 ]; then
    cat << EOF | sudo tee /etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
Identifier "Intel Graphics"
Driver "intel"
Option "AccelMethod" "sna"
Option "TearFree" "true"
EndSection
EOF
fi

# TODO: add a section to install nvidia drivers if necessary?

# kill firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
sudo usermod -aG vboxusers $(whoami)
