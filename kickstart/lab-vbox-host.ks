# this is designed to be used as a virtualbox template

install
cdrom

# add in some repos
repo --name=epel --baseurl=http://download.fedoraproject.org/pub/epel/7/x86_64

# force text mode, please
text

# network config
network  --bootproto=dhcp --device=eno1 --hostname=spinne.xthorsworld.com --noipv6 --activate

# System authorization information
auth --enableshadow --passalgo=sha512

# System language
lang en_US.UTF-8

# disable firstboot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# Set SELinux to enforcing (Which is default)
selinux --enforcing

# Set the timezone
timezone America/Denver --isUtc

# We are the boot loader
bootloader --location=mbr --driveorder=nvme0n1

# Set the root password
rootpw p@ssw0rd

# enable logging so we can see what happened
logging --level=debug

# disk configuration - designed to fit in default 8GB VDI that VBox creates :)
clearpart --drives=nvme0n1 --all --initlabel
part /boot --fstype="xfs"  --ondisk=nvme0n1 --size=1024
part pv.2  --fstype="lvmpv" --ondisk=nvme0n1 --size=1   --grow
volgroup vg0 --pesize=4096 pv.2
logvol /      --fstype="xfs" --name="root" --vgname="vg0" --size=16384 # 16GB root 
logvol /var   --fstype="xfs" --name="var" --vgname="vg0" --size=8192 # 8GB for var, probably too much
logvol swap   --vgname="vg0" --size=2048 --name=swap # 2GB swap
logvol /home  --fstype="xfs" --name="home" --vgname="vg0" --size=4096 --grow # home gets everything else

# Reboot after installation
reboot --eject

# enable firewalld service  
firewall --enable

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
bind-utils
tcpdump
lighttpd
# necessary for the freaking vbox guest additions
gcc
kernel-devel
kernel-headers
dkms
make
bzip2
p7zip-plugins
httpd
php
%end

%post --log=/root/ks-post.log
# add my ssh pubkey to this server
mkdir -m0700 /root/.ssh/

cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor0-ssh-key
EOF

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
restorecon -R /root/.ssh/

# install the cloudinit php script 
systemctl enable httpd 
cat > /var/www/html/cloudinit.php << EOF 
<?php
if (strpos(\$_SERVER['REQUEST_URI'],'meta-data') !== false) {
	if(isset(\$_GET["vmname"])) {
		echo 'instance-id: 1
local-hostname: ' . htmlspecialchars(\$_GET["vmname"]);
	} else {
		header('HTTP/1.1 404 Not Found');
	}
} elseif(strpos(\$_SERVER['REQUEST_URI'],'user-data') !== false) {
	echo '#cloud-config
users:
    - name: root
      passwd: toor
      ssh_authorized_keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
timezone: America/Denver
runcmd:
    - touch /etc/cloud/cloud-init.disabled
    - eject cdrom
' ;
}
?>
EOF

# install virtualbox repo
curl http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo | tee /etc/yum.repos.d/virtualbox.repo

# install salt repo
yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-latest.el7.noarch.rpm 

# install updates 
yum -y upgrade 
%end

# this allows the log file to persist a reboot... seriously, RedHat, this should be an option without the hack
%post --nochroot
cp /tmp/anaconda.log /mnt/sysimage/root/anaconda.log
%end 
