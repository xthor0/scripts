# this is designed to be used as a virtualbox template

install
cdrom

# add in some repos
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/7/x86_64

# force text mode, please
text

# can we put network here? we may have to move it - if we don't do this the system boots without a NIC
network --onboot yes --device=enp0s3 --bootproto=dhcp --noipv6 --activate
network  --bootproto=static --device=enp0s8 --ip=10.187.88.1 --netmask=255.255.255.0 --noipv6 --activate
network  --hostname=router.lab

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
bootloader --location=mbr --driveorder=sda

# Set the root password
rootpw p@ssw0rd

# disk configuration - designed to fit in default 8GB VDI that VBox creates :)
clearpart --drives=sda --all --initlabel
part /boot --fstype="ext4"  --ondisk=sda --size=512
part pv.2  --fstype="lvmpv" --ondisk=sda --size=1   --grow
volgroup vg0 --pesize=4096 pv.2
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
dnsmasq
# the below was stolen shamelessly from https://www.centos.org/forums/viewtopic.php?t=47262 (last post)
-aic94xx-firmware*
-alsa-*
-biosdevname
-btrfs-progs*
-dracut-network
-iprutils
-ivtv*
-iwl*firmware
-libertas*
-kexec-tools
-plymouth*
-postfix
-NetworkManager-wifi
%end

%post
# add my ssh pubkey to this server
mkdir -m0700 /root/.ssh/

cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfu9au0EkA02pnruvqLcquikJim4VgQg61YxwG0LauDv+qM0j4EPDfzQtN3GMfyPs/i79NeNNndvfc2vqYJt8sVwjegoNF9h8jDytaWZ7zzblhY7qBkwtAVZ6ADgTY/w28CkB80dRPey2E4FGxING6AzieYwoHsKmaMt6IumOJlo01HoeouW7OP8qg51n8EHKmov5oA4DzzDx/UkS0aDDKpp38hIj0DHkcK8jhi5eZoEM7hOgaW+Efj6t/XzpoOhQVytsJXxqzZ/+4UDVfJ3FTQLmI+hdymbyxYL5i2FCK5kMldGyZuZz9h9ikM9xHWSmKIeTevut9/chveUR/W/E2qqziqm8fCoZZ2WIHfhy+Bt0OcLUro2Gpe7S0i8uCbvNK60OpE+hf9GxAv+G0UUCuSxJtKqrpgi5xNifvXaT3pk5Uxr/1+g+tiMyoaZxCmJPz7IZU7y9lurTAhYT0HgkcU4OZpGS1/x+rGu2f0un3UkUJyYFpgjfjw9iu9Y/0H7k= bbrown@bbrown-l
EOF

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
restorecon -R /root/.ssh/

### firewall should be off. We can always turn it back on with Salt later.
systemctl disable firewalld

### turn on dnsmasq
systemctl enable dnsmasq

### create config file for dnsmasq
cat << EOF > /etc/dnsmasq.d/lab.conf
domain=lab
dhcp-option=6,10.187.88.1
dhcp-range=10.187.88.20,10.187.88.250,2h
dhcp-option=3,10.187.88.1
EOF

cat << EOF >> /etc/rc.d/rc.local
# hacky hack way to make this box a router for virtualbox lab...
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
EOF

# ip forwarding
echo net.ipv4.ip_forward=1 > /etc/sysctl.d/98-ip-forward.conf

# Make sure new rc.local is also executable
chmod 755 /etc/rc.d/rc.local

# End of kickstart script
%end
