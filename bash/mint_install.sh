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

# virtualbox
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian bionic contrib"

# vscode
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
rm /tmp/microsoft.gpg
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"

# update apt sources
sudo apt-get update

# install a bunch of packages
sudo apt-get install vim nmap vim-gnome conky-all lynx axel remmina-plugin-rdp freerdp-x11 terminator expect ncdu pwgen virtualbox-5.2 vlc xfonts-terminus code git nemo-dropbox htop putty-tools

# stupid vscode
echo "# commented out because vscode keeps adding this" | sudo tee /etc/apt/sources.list.d/vscode.list

# pycharm
cd $HOME && wget https://download.jetbrains.com/python/pycharm-community-2018.2.5.tar.gz -O - | tar zxvf

# telegram
cd $HOME && wget https://telegram.org/dl/desktop/linux -O - | tar Jxv

## ONLY NECESSARY FOR LAPTOPS
chassistype=$(hostnamectl status | grep Chassis | awk '{ print $2 }')
if [ "$chassistype" == "laptop" ]; then
    # install tlp/powertop
    sudo apt-get -y install tlp powertop

    # build a service for powertop
    echo "Installing powertop as a service..."
    cat << EOF | sudo tee /etc/systemd/system/powertop.service
[Unit]
Description=PowerTOP auto tune

[Service]
Type=idle
Environment="TERM=dumb"
ExecStart=/usr/sbin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF

    # reload systemd
    sudo systemctl daemon-reload

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
sudo sed -i 's/^hosts:.*mdns4_minimal.*/hosts:      files dns myhostname/g' /etc/nsswitch.conf

# cypher cert from Active Directory
# will need tweaking to match CHG's environment... this is for PL
# grep -q stormwind.local /etc/resolv.conf
# if [ $? -eq 0 ]; then
#  wget --quiet --no-check-certificate --http-user=benjamin.brown --ask-password 'https://pfprdd1ca01.stormwind.local/certsrv/certnew.cer?ReqID=CACert&Renewal=0&Mode=inst&Enc=b64' -O pfprdd1ca01.crt
#  cat pfprdd1ca01.crt | sudo tee /etc/pki/ca-trust/source/anchors/pfprdd1ca01.crt && sudo update-ca-trust && rm cypher.crt
# fi

# virtualbox needs you to be a member of vboxusers if you have a prayer of using USB
sudo usermod -aG vboxusers $(whoami)

# done
echo "Configuration of Mint is complete. Exiting."
exit 0