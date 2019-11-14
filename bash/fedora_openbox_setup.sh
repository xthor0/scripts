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
    echo "Exiting! The output of 'sudo whoami' did not come back with the string 'root'."
    exit 255
fi

############
# Package installs
############

# add additional packages that don't come with Fedora
rpm -qa | egrep -q 'rpmfusion-(free|nonfree)'
if [ $? -eq 1 ]; then
    echo "Installing rpmfusion release pacakges..."
    sudo su -c 'dnf -y install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'
else
    echo "rpmfusion release packages are already installed."
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

# enable coprs
for repo in dawid/better_fonts; do
    sudo dnf copr list | grep -q ${repo}
    if [ $? -eq 1 ]; then 
        echo "Installing copr repo ${repo}..."
        sudo dnf -y copr enable ${repo}
    else
        echo "copr repo ${repo} is already installed."
    fi
done

# brave browser
sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/ && sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

# I'll need to do some updating here...
sudo dnf -y install vim-enhanced nmap vim-X11 conky lynx axel freerdp terminator expect ncdu pwgen vlc kernel-devel fontconfig-enhanced-defaults fontconfig-font-replacements telegram-desktop elfutils-libelf-devel fuse-exfat htop remmina-plugins-rdp arc-theme htop exfat-utils git code putty gimp hexedit flatpak f3 screen p7zip-plugins iperf VirtualBox-6.0 xfce4-power-manager tint2 volumeicon Thunar xfce4-notifyd blueman tlp x11-ssh-askpass brave-browser

# install Slack from flatpak
flatpak install https://flathub.org/repo/appstream/com.slack.Slack.flatpakref

# upgrade everything
sudo dnf -y upgrade

############
# app config
############

# create directories
mkdir ${HOME}/.fonts ${HOME}/tmp >& /dev/null
pushd ${HOME}/tmp

# we need to copy in a shload of dotfiles... mostly for Openbox and Terminator, but... yeah.
# I need something sexier than curl | tar but... it's 12 AM :)
wget https://xw-killer-dotfiles.s3-us-west-1.amazonaws.com/killer_dotfiles.tgz && tar zxvf killer_dotfiles.tgz -C ${HOME}

# also - Terminus TTF. Download the zip and stuff the ttf files in ~/.fonts - otherwise, terminator
# will be ugly and unhappy
if [ $? -eq 0 ]; then
  wget https://files.ax86.net/terminus-ttf/files/latest.zip
  if [ $? -eq 0 ]; then
    unzip latest.zip && mv terminus-ttf-*/*.ttf ${HOME}/.fonts && fc-cache -f -v
  fi
else
  echo "Can't cd to ${HOME}/tmp -- exiting."
  exit 255
fi

popd

# virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
sudo usermod -aG vboxusers $(whoami)

############
# system config
############

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

# nss-mdns is evil
rpm -qa | grep -q plasma-workspace
if [ $? -eq 0 ]; then
  # KDE is installed - don't remove nss-mdns or it'll remove KDE
  sudo sed -i 's/^hosts:.*mdns4_minimal.*/hosts:      files dns myhostname/g' /etc/nsswitch.conf
else
  sudo dnf -y remove nss-mdns
fi

# kill firewalld
sudo systemctl disable firewalld
sudo systemctl stop firewalld

############
# END
############

echo "You should really reboot."
exit 0
