#!/bin/bash

# Disable IPv6
echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
/sbin/sysctl -p

#sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

# Set local hostname
hostnamectl set-hostname $1

# install epel and some packages I like
yum -y install epel-release
yum -y install wget screen rsync vim-enhanced bind-utils net-tools bash-completion bash-completion-extras policycoreutils-python

# Install Salt repo
yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm

# Expire YUM cache
yum clean expire-cache

# Install Salt
yum install -y salt salt-minion

# set master so that Salt can find it
echo "hash_type: sha256
id: ${1}.localdev
log_level: info
master: 10.187.88.10" | tee /etc/salt/minion

# remove static minion_id file
rm -f /etc/salt/minion_id

# Set Salt Minion to start at reboot
systemctl enable salt-minion.service

# Start Salt Minion service
systemctl start salt-minion.service

# key should be auto-accepted on master at this point!
