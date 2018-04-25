#!/bin/bash

# make sure we're running this as a non-root user...
if [ "$(whoami)" == "root" ]; then
    echo "You should not run this script as root - instead, it will invoke commands"
    echo "using 'sudo' where necessary."
    exit 255
fi

# make sure we have sudo rights
echo "Checking to make sure your account has 'sudo' privileges..."
echo "Script will execute 'sudo whoami' - please enter your password if prompted."
if [ "$(sudo whoami)" != "root" ]; then
    echo "Command exited with a non-zero status."
    exit 255
fi

# add additional packages that don't come with Fedora by default
echo "Installing rpmfusion release pacakges..."
sudo su -c 'dnf install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'

# google fedora repo
echo "Installing official Google Chrome repository..."
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

# atom editor
sudo dnf copr enable mosquito/atom

# improve fonts
sudo dnf copr enable dawid/better_fonts

# do a full upgrade
sudo dnf -y upgrade

# install all the packages
sudo dnf -y install vim-enhanced nmap vim-X11 conky lynx axel freerdp terminator expect ncdu pwgen google-chrome-stable VirtualBox-5.1 vlc terminus-fonts-console terminus-fonts atom kernel-devel fontconfig-enhanced-defaults fontconfig-font-replacements

## ONLY NECESSARY FOR LAPTOPS
chassistype=$(hostnamectl status | grep Chassis | awk '{ print $2 }')
if [ "$chassistype" == "laptop" ]; then
    # install tlp/powertop
    sudo dnf -y install tlp powertop

    # start powertop and tlp at boot
    sudo systemctl enable powertop
    sudo systemctl enable tlp
    sudo systemctl start powertop
    sudo systemctl start tlp
else
    # for non-laptops - enable sshd
    sudo systemctl enable sshd && sudo systemctl start sshd
fi

# nss-mdns is evil
### don't do this on KDE!!!
###sudo dnf -y remove nss-mdns
cp /etc/nsswitch.conf ~/nsswitch.conf.bkup
sed -i 's/^hosts:.*mdns4_minimal.*/hosts:      files dns myhostname/g' /etc/nsswitch.conf

# cypher cert from Active Directory
grep -q stormwind.local /etc/resolv.conf
if [ $? -eq 0 ]; then
  wget --quiet --no-check-certificate --http-user=benjamin.brown --ask-password 'https://pfprdd1ca01.stormwind.local/certsrv/certnew.cer?ReqID=CACert&Renewal=0&Mode=inst&Enc=b64' -O pfprdd1ca01.crt
  cat pfprdd1ca01.crt | sudo tee /etc/pki/ca-trust/source/anchors/pfprdd1ca01.crt && sudo update-ca-trust && rm cypher.crt
fi

# telegram - this will extract to $HOME/Telegram
cd $HOME && wget https://telegram.org/dl/desktop/linux -O - | tar Jxv 
$HOME/Telegram/Telegram &

# kill firewalld
sudo systemctl disable firewalld

# virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
sudo usermod -aG vboxusers $(whoami)
