# this is designed to be used as a virtualbox template

#install
#cdrom

# add in some repos
#repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/7/x86_64
#repo --name=saltstack --baseurl=https://repo.saltstack.com/yum/redhat/7/x86_64/latest
url --url="http://ord.mirror.rackspace.com/rocky/8.5/BaseOS/x86_64/os/"
repo --name=epel --baseurl=https://mirrors.xmission.com/fedora-epel/8/Everything/x86_64/

# force text mode, please
text

# can we put network here? we may have to move it - if we don't do this the system boots without a NIC
#network --device=link --bootproto=dhcp
#network --onboot yes --device=link --bootproto=dhcp --noipv6 --activate --hostname=blah
network  --bootproto=static --device=eno1 --gateway=10.200.54.1 --ip=10.200.54.10 --netmask=255.255.255.0 --nameserver 10.200.54.1 --noipv6 --vlanid 54 --hostname pok.xthorsworld.lab

# System authorization information
authconfig --enableshadow --passalgo=sha512

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

# not necessary with efi, I don't think
#bootloader --location=none
bootloader --location=mbr --boot-drive=nvme0n1 # guess I was fucking wrong

# Set the root password
# I've redacted the salted hashes - I generated them on Linux with this command:
# mkpasswd -m sha512crypt
rootpw --iscrypted $redacted

# add a user
user --name=xthor --groups=wheel --password=$redacted --iscrypted

# disk configuration - designed to fill whatever is provided
clearpart --drives=nvme0n1 --all --initlabel
part /boot/efi --fstype=efi --size=512
part /boot --fstype="ext4"  --ondisk=nvme0n1 --size=1024
part pv.2  --fstype="lvmpv" --ondisk=nvme0n1 --size=1   --grow
volgroup vg0 --pesize=4096 pv.2
logvol /    --fstype="ext4" --name="root" --vgname="vg0" --size=4096 --grow

# Reboot after installation
reboot --eject

%packages
@core --nodefaults
screen
vim-enhanced
bash-completion
wget
rsync
epel-release
%end

%post
# add my ssh pubkey to this server
mkdir -m0700 /home/xthor/.ssh/

cat <<EOF >/home/xthor/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf imported-openssh-key
EOF

### set permissions
chmod 0600 /home/xthor/.ssh/authorized_keys

### fix up selinux context
restorecon -R /home/xthor/.ssh/

### change ownership to correct user
chown -R xthor:xthor /home/xthor/.ssh

### allow sudo without password
sed -i 's/^%wheel/\#%wheel/g' /etc/sudoers
sed -i 's/^\# %wheel/%wheel/g' /etc/sudoers

### firewall should be off. We can always turn it back on with Salt later.
systemctl disable firewalld

# End of kickstart script
%end
