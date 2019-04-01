#!/bin/bash

cat << EOF > /usr/local/minion-setup
#!/bin/bash

# meant to be run via systemd on a vbox minion
# an easier way to deploy since salt-cloud doesn't work

newHostName=$(VBoxControl --nologo guestproperty get GuestName | awk '{ print $2 }')

# make sure the result isn't zero length (indicating VBoxControl doesn't work), or "value" (not set)
if [ ${#newHostName} -eq 0 ]; then
  echo "vbox guest property not set - exiting."
  exit 255
elif [ "${newHostName}" == "value" ]; then
  echo "vbox guest property not set - exiting."
  exit 255
fi

# set the hostname
hostnamectl set-hostname ${newHostName}.lab

# point the minion at the right master
echo "master: 10.187.88.10" | tee /etc/salt/minion

# start/enable Salt
systemctl enable salt-minion
systemctl start salt-minion

# get rid of the evidence
rm /etc/systemd/system/minion-setup.service
rm /usr/local/deploy-minion

# fin
exit 0
EOF

chmod 755 /usr/local/minion-setup

cat << EOF > /etc/systemd/system/minion-setup.service
[Unit]
Description=Bootstrap Salt
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/minion-setup
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

# I don't know why Debian enables this by default, but...
systemctl disable salt-minion

# make sure the script we created executes at boot
systemctl enable minion-setup

# allow remote login via SSH as root
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# add my SSH key to the root user
mkdir /root/.ssh && echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthors-key' > /root/.ssh/authorized_keys && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys