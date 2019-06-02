#!/bin/bash

# this script is bare right now - eventually, I'd like to make it configure everything necessary to run a full-featured Openbox
# DE on any recent version of Fedora, no matter which platform was installed

sudo dnf install openbox tint2 obconf compton volumeicon nitrogen obmenu xfce4-notifyd conky xscreensaver lxqt-openssh-askpass xfce4-power-manager blueman arandr thunar gmrun leafpad lxappearance network-manager-applet xbacklight flameshot

# remove KDE without destroying your system
rpm -qa | grep plasma | xargs sudo dnf --setopt clean_requirements_on_remove=False remove -y
rpm -qa | grep kf5 | xargs sudo dnf --setopt clean_requirements_on_remove=False remove -y
sudo dnf remove kde-settings\*

# find the compton.conf and openbox autostart in the dotfiles directory - should be all you need
