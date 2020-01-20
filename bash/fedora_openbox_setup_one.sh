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

# get manufacturer
manufacturer=$(dmidecode | grep -A3 '^System Information' | grep Manufact | awk '{ print $2 }')
if [ "${manufacturer}" == "System76" ]; then
  dnf -y copr enable szydell/system76 && dnf -y install system76-dkms system76-driver system76-firmware firmware-manager system76-io-dkms && systemctl enable system76-firmware-daemon
fi

# fin
exit 0
