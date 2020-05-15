# this is designed to be used as a virtualbox template

install
url --url http://mirror.xmission.com/centos/7/os/x86_64/

# add in some repos
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/7/x86_64

# force text mode, please
text

# can we put network here? we may have to move it - if we don't do this the system boots without a NIC
#network --device=link --bootproto=dhcp
#network --onboot yes --device=eno1 --gateway=10.200.99.1 --ip=10.200.99.32 --netmask=255.255.255.0 --noipv6 --vlanid 3 --nameserver=10.200.99.1 --interfacename=vlan03 --activate
network --bootproto=static --device=eno1 --ip=10.200.99.32 --netmask=255.255.255.0 --onboot=yes --noipv6 --activate --vlanid=3 --interfacename=vlan03 --nameserver=10.200.99.1 --gateway=10.200.99.1 --activate
network --hostname=ragno.xthorsworld.com

# System authorization information
auth --enableshadow --passalgo=sha512

# System language
lang en_US.UTF-8

# disable firstboot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# Disable firewall (We use hardware firewalls)
firewall --disabled

# Set SELinux to enforcing (Which is default)
selinux --enforcing

# Set the timezone
timezone America/Denver --isUtc

# We are the boot loader
#bootloader --location=partition

# Set the root password
rootpw r0ck0n

# disk configuration - designed to fit in default 8GB VDI that VBox creates :)
clearpart --drives=nvme0n1 --all --initlabel
part /boot/efi --fstype=efi --size=512
part /boot --fstype="xfs"  --ondisk=nvme0n1 --size=1024
part pv.01  --fstype="lvmpv" --ondisk=nvme0n1 --size=1   --grow
volgroup vg0 --pesize=4096 pv.01
logvol swap --fstype="swap" --name="swap" --vgname="vg0" --size=2048
logvol /    --fstype="ext4" --name="root" --vgname="vg0" --size=4096 --grow

# Reboot after installation
reboot --eject

%packages
@core --nodefaults
screen
vim-enhanced
policycoreutils-python
bash-completion
wget
rsync
deltarpm
yum-plugin-fastestmirror
epel-release
%end

%post
# add my ssh pubkey to this server
mkdir -m0700 /root/.ssh/

cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf imported-openssh-key
EOF

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
restorecon -R /root/.ssh/

### firewall should be off. We can always turn it back on with Salt later.
systemctl disable firewalld

# End of kickstart script
%end
