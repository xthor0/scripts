#!/bin/bash

###########
# TO-DO LIST
###########

######
# 1. weather
#    tint2rc is using `weather -i` which doesn't work.
#    figure out how to use something with conky. a few things I've played with:
#    curl -s wttr.in/84118 | sed -n '3,7{s/\d27\[[0-9;]*m//g;s/^..//;s/ *$//;p}'
#    inxi -w --weather-unit i

# 2. ask questions before installing the packages below (see comment about asking questions :)
# 3. turn this into something like the crunchbang script that gets run when the user logs in for the first time
# 4. change plymouth theme to something... not spinner.

### BREAKAGES
# script exits after flatpak runs. No idea why.

# midori sucks, so I installed chromium (until this script installed brave). Removing nss-mdns also removes chromium.
# since I don't work anyplace using .local domain names anymore (and I'm really not likely to), maybe I should just leave nss-mdns alone.

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
    fedrel=$(awk '{ print $3 }' /etc/redhat-release)
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

# base packages
sudo dnf -y install vim-enhanced nmap vim-X11 lynx axel freerdp terminator expect ncdu pwgen vlc kernel-devel fontconfig-enhanced-defaults fontconfig-font-replacements telegram-desktop fuse-exfat htop remmina-plugins-rdp arc-theme htop exfat-utils git code putty gimp hexedit flatpak f3 screen p7zip-plugins iperf tint2 Thunar xfce4-notifyd tlp x11-ssh-askpass brave-browser heisenbug-backgrounds-base openbox obconf compton volumeicon nitrogen conky xscreensaver lxqt-openssh-askpass xfce4-power-manager blueman arandr leafpad lxappearance network-manager-applet xbacklight flameshot playerctl mate-calc
if [ $? -ne 0 ]; then
  echo "Error installing packages - review output above. Exiting."
  exit 255
fi

# if we're a VirtualBox guest, install these apps
lspci | grep -q 'InnoTek Systemberatung GmbH VirtualBox Guest Service'
if [ $? -eq 0 ]; then
  echo "Running as a VM, adjusting configuration..."

  # let's kill xscreensaver, as there's really no reason to keep it running on a VM, we already have OS lock screens
  echo "Removing xscreensaver..."
  sudo dnf -y remove xscreensaver-base

  # the Fedora supplied virtualbox guest additions work great - except, shared folders do not work
  echo "Installing akmod-VirtualBox..."
  sudo dnf -y install akmod-VirtualBox
  retval=$?
else
  # if we're bare metal, install VirtualBox hypervisor
  echo "Installing VirtualBox-6.0..."
  sudo dnf -y install elfutils-libelf-devel VirtualBox-6.0
  retval=$?
fi
if [ ${retval} -ne 0 ]; then
  echo "Error installing packages - review output above. Exiting."
  exit 255
fi

### WE SHOULD ASK before installing the stuff below
sudo dnf -y install podman-docker
if [ $? -eq 0 ]; then
  sudo touch /etc/containers/nodocker # this will prevent docker commands from telling you about podman-docker
else
  echo "Error installing podman-docker."
  read -n1 -s -r -p "Press any key to continue."
fi

# enable tlp
sudo systemctl enable tlp

# install Slack from flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub com.slack.Slack
if [ $? -ne 0 ]; then
  read -n1 -s -r -p "Flatpak configuration failed, consult the error message above and press a key to continue."
fi

# upgrade everything
sudo dnf -y upgrade
if [ $? -ne 0 ]; then
  echo "Error updating the system. Take a look at the error before proceeding."
  read -n1 -s -r -p "Press any key to continue."
fi

############
# app config
############

# create directories
mkdir ${HOME}/.fonts ${HOME}/tmp >& /dev/null
pushd ${HOME}/tmp
if [ $? -ne 0 ]; then
  echo "Can't cd to ${HOME}/tmp -- exiting."
  exit 255
fi

# we need to copy in a shload of dotfiles... mostly for Openbox and Terminator, but... yeah.
# I need something sexier than curl | tar but... it's 12 AM :)
wget https://xw-killer-dotfiles.s3-us-west-1.amazonaws.com/killer_dotfiles.tgz && tar zxvf killer_dotfiles.tgz -C ${HOME}
if [ $? -ne 0 ]; then
  echo "Unable to download dotfiles tarball -- exiting."
  exit 255
fi

# also - Terminus TTF. Download the zip and stuff the ttf files in ~/.fonts - otherwise, terminator
# will be ugly and unhappy
wget https://files.ax86.net/terminus-ttf/files/latest.zip
if [ $? -eq 0 ]; then
  unzip latest.zip && mv terminus-ttf-*/*.ttf ${HOME}/.fonts && fc-cache -f -v
else
  echo "Unable to download Terminus TTF font and install. Exiting."
  exit 255
fi

popd

# virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
echo "Adding $(whoami) to vboxusers group..."
sudo usermod -aG vboxusers $(whoami)

############
# system config
############

# if this is virtualbox - a reminder to the user that guest additions that are preinstalled
# won't work with the display unless the adapter type is changed
# VMware SVGA II Adapter
lspci | grep -q VirtualBox
if [ $? -eq 0 ]; then
  lspci | grep -q 'VMware SVGA II Adapter'
  if [ $? -eq 0 ]; then
    echo "Please change your VirtualBox system properties!"
    echo
    echo "Currently, your display adapter is set to the VMSVGA display adapter."
    echo "If you change it to VBoxVGA, the guest additions installed by default"
    echo "in Fedora will allow the display to be dynamically adjusted."
    echo
    echo "Press enter to continue..."
    read continue
  fi
fi

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

# make openbox default for LXDM
#sudo sed -i 's/^# session=\/usr\/bin\/startlxde/session=\/bin\/openbox/g' /etc/lxdm/lxdm.conf
echo -e "[Desktop]\nsession=/usr/share/xsessions/openbox.desktop" > ${HOME}/.dmrc

############
# END
############

echo "You should really reboot."
exit 0
