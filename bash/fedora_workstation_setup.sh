#!/bin/bash

# TO DO!
: <<'END'
    There are a few things I need to do here:

    1. idempotency - make the script CHECK to see if things are installed BEFORE installing them.
    2. make it flavor independent - check for cinnamon and install nemo-dropbox, check for gnome and install nautilus-dropbox (just a couple examples)
END

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
    echo "Exiting! The output of 'sudo whoami' did not come back with the string 'root'."
    exit 255
fi

# add additional packages that don't come with Fedora

rpm -qa | egrep -q 'rpmfusion-(free|nonfree)'
if [ $? -eq 1 ]; then
    echo "Installing rpmfusion release pacakges..."
    sudo su -c 'dnf install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'
else
    echo "rpmfusion release packages are already installed."
fi

# google fedora repo
if [ -f /etc/yum.repos.d/google-chrome.repo ]; then
  echo "Google Chrome repo already installed."
else
  echo "Installing official Google Chrome repository..."
  cat << EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF
fi

for repo in dawid/better_fonts phracek/PyCharm; do
    sudo dnf copr list | grep -q ${repo}
    if [ $? -eq 1 ]; then 
        echo "Installing copr repo ${repo}..."
        sudo dnf -y copr enable ${repo}
    else
        echo "copr repo ${repo} is already installed."
    fi
done

# spotify
if [ -f /etc/yum.repos.d/fedora-spotify.repo ]; then
    echo "Fedora Spotify repo already enabled."
else
    echo "Installing Spotify repo..."
    sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-spotify.repo
fi

# fedora-multimedia gets you makemkv!
if [ -f /etc/yum.repos.d/fedora-multimedia.repo ]; then
    echo "Fedora Multimedia repo is already installed."
else
    echo "Installing Fedora Multimedia repo..."
    sudo dnf config-manager --add-repo=https://negativo17.org/repos/fedora-multimedia.repo
fi

# vscode
if [ -f /etc/yum.repos.d/vscode.repo ]; then
    echo "vscode repo is already installed."
else
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
fi

# virtualbox
# if a version of VirtualBox is too new for this version of Fedora, this script MAY fail... I'll have to test it.
if [ -f /etc/yum.repos.d/virtualbox.repo ]; then
    echo "VirtualBox repo already configured."
else
    fedrel=$(lsb_release -r | awk '{ print $2 }')
    vbcheck=$(curl --write-out %{http_code} --silent --output /dev/null http://download.virtualbox.org/virtualbox/rpm/fedora/${fedrel})
    curl http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo | sudo tee /etc/yum.repos.d/virtualbox.repo
    if [ ${vbcheck} -eq 404 ]; then
        echo "Fedora ${fedrel} is not supported by VirtualBox yet. 404 received checking download.virtualbox.org."
        echo "The DNF command below may fail..."
        read -n 1 -s -r -p "Press any key to continue (or CTRL-C to exit)"
    fi
fi

# do a full upgrade
echo "Performing full dnf upgrade..."
sudo dnf -y upgrade

# TODO: if 'dnf upgrade' installs a new kernel, virtualbox will have issues running /sbin/vboxconfig!
# I need to put in a check here that tells the user to reboot if there's a new kernel.

echo "Checking to see if kernel was upgraded..."
current_kernel=$(uname -r)
new_kernel=$(sudo grubby --default-kernel | cut -b 15-)

if [ ${current_kernel} != ${new_kernel} ]; then
	echo "A new kernel was installed! We need to reboot before proceeding."
	echo "Please run this script again after rebooting."
	read -n1 -s -r -p "Press any key to reboot..."
	reboot
fi

# install all the packages
echo "Installing a bunch of packages..."
sudo dnf -y install vim-enhanced nmap vim-X11 conky lynx axel freerdp terminator expect ncdu pwgen VirtualBox-6.0 vlc kernel-devel fontconfig-enhanced-defaults fontconfig-font-replacements telegram-desktop elfutils-libelf-devel fuse-exfat htop pycharm-community spotify remmina-plugins-rdp arc-theme htop exfat-utils git code putty gimp hexedit flatpak openldap-clients f3 screen p7zip-plugins iperf

# install distro-specific packages
rpm -qa | grep -q cinnamon-desktop
if [ $? -eq 0 ]; then
  sudo dnf -y install nemo-dropbox
else
  sudo dnf -y install nautilus-dropbox
fi

## ONLY NECESSARY FOR LAPTOPS
chassistype=$(hostnamectl status | grep Chassis | awk '{ print $2 }')
if [ "$chassistype" == "laptop" ]; then
    # install tlp/powertop
    echo "Installing TLP & powertop (chassis is ${chassistype})..."
    sudo dnf -y install tlp powertop

    # start powertop and tlp at boot
    sudo systemctl enable powertop
    sudo systemctl enable tlp
    sudo systemctl start powertop
    sudo systemctl start tlp
else
    # for non-laptops - enable sshd
    echo "Enabling SSHD so it starts at boot..."
    sudo systemctl enable sshd && sudo systemctl start sshd
fi

# nss-mdns is evil
rpm -qa | grep -q plasma-workspace
if [ $? -eq 0 ]; then
  # KDE is installed - don't remove nss-mdns or it'll remove KDE
  sudo sed -i 's/^hosts:.*mdns4_minimal.*/hosts:      files dns myhostname/g' /etc/nsswitch.conf
else
  sudo dnf -y remove nss-mdns
fi

# install Slack from flatpak
flatpak install https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

# install a bunch of media stuff - optional
echo "Do you wish to install stuff for your home machine (steam, makemkv, HandBrake)?"
read -p "(Y/N): " yesno
result=$(echo ${yesno} | tr [:upper:] [:lower:])
if [ "${result}" == "y" ]; then
  sudo dnf -y install makemkv HandBrake-gui steam
fi

# keeping this in case I ever need it again...
# cypher cert from Active Directory
#grep -q stormwind.local /etc/resolv.conf
#if [ $? -eq 0 ]; then
#  wget --quiet --no-check-certificate --http-user=benjamin.brown --ask-password 'https://pfprdd1ca01.stormwind.local/certsrv/certnew.cer?ReqID=CACert&Renewal=0&Mode=inst&Enc=b64' -O pfprdd1ca01.crt
#  cat pfprdd1ca01.crt | sudo tee /etc/pki/ca-trust/source/anchors/pfprdd1ca01.crt && sudo update-ca-trust && rm cypher.crt
#fi

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

# install nvidia drivers if we're running a supported card...
lspci | grep -qi VGA.*NVIDIA
if [ $? -eq 0 ]; then
  echo "Do you want to install the nvidia drivers? Make sure your card is supported!"
  read -p "(Y/N): " yesno
  result=$(echo ${yesno} | tr [:upper:] [:lower:])
  if [ "${result}" == "y" ]; then
    sudo dnf -y install nvidia-driver nvidia-settings
  fi
fi

# kill firewalld
sudo systemctl disable firewalld
sudo systemctl stop firewalld

# virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
sudo usermod -aG vboxusers $(whoami)
echo "You should log out now if you want to use USB devices with VirtualBox."

# we're done
echo "$(basename $0) completed successfully!"
exit
