# This script create a Centos Minimal Unattended ISO

# This method is based on excellent article http://pyxlmap.net/technology/software/linux/custom-centos-iso
# 
# This script has be tested with CentOS 6.5
# TODO:
# * test package update to reduce the update task on the target system. The following command downloads all updates :
#   (cd $CENTOS_CUSTOM_PATH/Packages ; yumdownloader $(for i in *; { echo ${i%%-[0-9]*}; } ) )

# Some global settings :
CENTOS_SOURCE_ISO_URL=http://mirror.facebook.net/centos/6.10/isos/x86_64/CentOS-6.10-x86_64-minimal.iso
CENTOS_CUSTOM_PATH=/home/build
ISO=/home/centos610auto.iso
ISO_MOUNTPOINT=/mnt

cd
test -f $(basename $CENTOS_SOURCE_ISO_URL) || curl -O $CENTOS_SOURCE_ISO_URL

yum -y install rsync yum-utils createrepo genisoimage isomd5sum

mount -o loop,ro ~/$(basename $CENTOS_SOURCE_ISO_URL) $ISO_MOUNTPOINT

mkdir -p $CENTOS_CUSTOM_PATH
cd $CENTOS_CUSTOM_PATH && rm -rf repodata/*
rsync --exclude=TRANS.TBL -av $ISO_MOUNTPOINT/ .

# Step 2 : add additional RPM in repository

cd $CENTOS_CUSTOM_PATH/Packages
yumdownloader openssh-server libcurl curl grep tzdata ca-certificates
#   (cd $CENTOS_CUSTOM_PATH/Packages ; yumdownloader $(for i in *; { echo ${i%%-[0-9]*}; } ) )

# Step 3

cd $CENTOS_CUSTOM_PATH/repodata
mv *x86_64.xml comps.xml && {
ls | grep -v comps.xml | xargs rm -rf
}

# Step 5

cd $CENTOS_CUSTOM_PATH
discinfo=$(head -1 .discinfo)
createrepo -u "media://$discinfo" -g repodata/comps.xml $CENTOS_CUSTOM_PATH || exit 1

# Step 6

# Get Keyboard and Timezone for current host
source  /etc/sysconfig/clock 
source  /etc/sysconfig/keyboard 

cat > $CENTOS_CUSTOM_PATH/ks.cfg << KSEOF
# Tell anaconda we're doing a fresh install and not an upgrade
install
text
reboot --eject
# Use the cdrom for the package install
cdrom
lang en_US.UTF-8
keyboard us
skipx
# You'll need a DHCP server on the network for the new install to be reachable via SSH
network --device eth0 --bootproto dhcp
# Set the root password below !! Remember to change this once the install has completed !!
rootpw toor
# Enable iptables, but allow SSH from anywhere
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512
selinux --enforcing
timezone --utc America/Denver
# Storage partitioning and formatting is below. We use LVM here.
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto rhgb quiet"
zerombr
clearpart --all --initlabel
part /boot --fstype ext4 --size=250
part pv.2 --size=3000 --grow
volgroup VolGroup00 --pesize=32768 pv.2
logvol / --fstype ext4 --name=LogVol00 --vgname=VolGroup00 --size=1024 --grow
logvol swap --fstype swap --name=LogVol01 --vgname=VolGroup00 --size=256 --grow --maxsize=512
# Defines the repo we created
repo --name="CentOS" --baseurl=file:///mnt/source --cost=100

# The below line installs the bare minimum WITH docs. If you don't want the docs, coment it out and uncomment the line below it.
%packages --nobase
#%packages --nobase --excludedocs
@core
%post
#---- Install Salt repo
rpm -ivh https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el6.noarch.rpm

#---- Install SSH key
mkdir -m0700 /root/.ssh/

cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIJou2nm1INiNlmx9Qi1+fwNKTd+YBkALUZRcY0xY6ArZZN2Qy+hFU7I0sFXNmTW41DzG19fP1F+f4bcj8X+aql8jDvphERZZgNGrAT8khsCqeDEiQHrhjMBTAPF3HWjkXle5bz31ya0aD7XeSX2ZqzyE+xUrmsNFBC31tkk5ON+Lg7RLpBKFgQz8g5YR8gtAUl0rs7SfLBb+jCaY2hmCIIihvNrtVRXmoCE0xWT0NvU/VgmGHYdedT8F5LhwYo/Rmmb/+QpTTycR5Ij8Ed6G4ym0WTZsGp+F4NQnF3Jw4O/7L9TG6wP83HuvtZoUhGPOAssInZ90NZZCLajYyrHv5 bebrown@Ben-Browns-MacBook-Pro.local 
EOF

### set permissions
chmod 0600 /root/.ssh/authorized_keys

### fix up selinux context
restorecon -R /root/.ssh/

### firewall should be off. We can always turn it back on with Salt later.
systemctl disable firewalld

# End of kickstart script
%end
KSEOF

# Inside the isolinux directory is a file named “isolinux.cfg”. Edit it and add the statement shown below.

sed -i -e '
s,timeout 600,timeout 60,
s,append initrd=initrd.img$,append initrd=initrd.img ks=cdrom:/ks.cfg biosdevname=0,' $CENTOS_CUSTOM_PATH/isolinux/isolinux.cfg 


cd $CENTOS_CUSTOM_PATH

mkisofs -r -R -J -T -v -no-emul-boot \
-boot-load-size 4 \
-boot-info-table \
-V "CentOS 6.4 x86_64 Custom Install" \
-p "YOUR NAME HERE" \
-A "CentOS 6.4 x86_64 Custom - 2013/04/21" \
-b isolinux/isolinux.bin \
-c isolinux/boot.cat \
-x "lost+found" \
--joliet-long \
-o $ISO .


implantisomd5 $ISO

# CLEANUP

umount $ISO_MOUNTPOINT

