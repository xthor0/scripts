### This needs more work
Spent a day playing with this. Wanted to capture as much detail as I could remember.
I need to write a similar guide for OS X.

## Setup Prep
1. install virtualbox 6
1. configure host-only network, IP forwarding, DHCP server
1. build a Salt Master
1. build a CentOS 7 template

## Host prep
1. host-only network configuration:
    * vboxmanage hostonlyif create
    * vboxmanage hostonlyif ipconfig vboxnet0 --ip 10.187.88.1 --netmask 255.255.255.0
1. Configure IP forwarding
    * sudo sysctl net.ipv4.ip_forward=1
    * also add "net.ipv4.ip_forward=1" to /etc/sysctl.d/99-sysctl.conf
1. Install dnsmasq, and add the following lines to /etc/dnsmasq.conf:
~~~
interface=vboxnet0
dhcp-range=10.187.88.20,10.187.88.250,2h
dhcp-option=3,10.187.88.1
dhcp-option=6,10.187.88.1
~~~

## Build a Salt master
1. install Salt's official yum repo
1. yum install salt-master
1. Document the reactor config that auto-adds a minion

## Template prep
1. install salt-minion from Salt's official yum repo
1. push deploy_minion.sh script to /opt on template
1. configure systemd script: /etc/systemd/system/saltdeploy.service
~~~
[Unit]
Description=Bootstrap Salt
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/deploy_minion.sh
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
~~~

1. enable service: systemctl enable saltdeploy
1. power off!

## Cloning
See new_vbox_minion_guest.sh for details
