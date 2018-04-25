#!/bin/bash

if [ "`whoami`" != "root" ]; then
	echo "You must be root to use this script."
	exit 255
fi

# are we already functionally aligned?
start=$(fdisk -l /dev/sda -u | grep sda1 | awk '{ print $3 }')
expr ${start} + 1 >&/dev/null
if [ $? -ne 0 ]; then
	echo "Could not determine starting sector for /dev/sda1. Manual alignment required."
	exit 255
fi

if [ ! -f /usr/bin/rescan-scsi-bus.sh ]; then
	yum -y install sg3_utils
	if [ $? -ne 0 ]; then
		echo "Error installing sg3_utils. Exiting."
		exit 255
	fi
fi

# let's see if we added the second drive to this VM
/usr/bin/rescan-scsi-bus.sh >& /dev/null

# wait for a few seconds...
echo "Waiting for devices to settle..."
sleep 10

if [ ! -b /dev/sdb ]; then
	echo "ERROR: /dev/sdb does not exist. Did you add a second virtual disk to this VM?"
	exit 255
fi

# make sure /dev/sdb has no partition table
/sbin/fdisk -l /dev/sdb 2>&1 | grep 'valid partition' > /dev/null
if [ $? -eq 1 ]; then
	echo "ERROR: /dev/sdb MAY have data on it! Manual alignment required."
	exit 255
fi

# make sure lvm0 exists, and that lvm1 doesn't -- again, otherwise manual work required
vgdisplay lvm0 >& /dev/null
proceed=0
if [ $? -eq 0 ]; then
	vgdisplay lvm1 >& /dev/null
	if [ $? -ne 5 ]; then
		proceed=1
	fi
else
	proceed=1
fi

if [ ${proceed} -eq 1 ]; then
	echo "ERROR: Either lvm0 doesn't exist, or you have more than one lvm. Manual alignment required."
	exit 255
fi

# give a final warning
echo "---WARNING!!!---"
echo "I'm about to do some potentially destructive work on your disks. I've done some sanity checks"
echo "to ensure I'm not about to do anything bad -- but this is your last chance to stop me before"
echo "I really break something."
echo
read -p "Type IFULLYUNDERSTANDTHECONSEQUENCES to proceed: " prompt

if [ "${prompt}" == "IFULLYUNDERSTANDTHECONSEQUENCES" ]; then
	echo "Partitioning /dev/sdb..."
	parted -s /dev/sdb mklabel msdos && parted -s /dev/sdb mkpart primary ext3 64s 499968s && parted -s /dev/sdb set 1 boot on && parted -s /dev/sdb mkpart primary 500032s 100% && parted -s /dev/sdb set 2 lvm on
	if [ $? -eq 0 ]; then
		echo "Partitioning complete."
		
		# wait for a few seconds...
		echo "Waiting for devices to settle..."
		sleep 10

		echo "Creating physical volume..."
		pvcreate /dev/sdb2 && vgextend lvm0 /dev/sdb2
		if [ $? -eq 0 ]; then
			echo "Physical volume creation complete."
			echo "Migrating data from sda2 to sdb2..."
			pvmove /dev/sda2 /dev/sdb2
			if [ $? -eq 0 ]; then
				echo "Migration complete."
				echo "Migrating boot partition to new disk..."
				vgreduce lvm0 /dev/sda2 && pvremove /dev/sda2 && umount /boot && sleep 5 && dd if=/dev/sda1 of=/dev/sdb1 && e2fsck -f /dev/sdb1 && resize2fs -p /dev/sdb1 && mount /dev/sdb1 /boot
				if [ $? -eq 0 ]; then
					echo "Boot migration complete."
					echo "Reinstalling grub..."
					echo -e "root (hd1,0)\nsetup (hd1)\nquit\n" | /sbin/grub --batch
					if [ $? -eq 0 ]; then
						echo "Alignment complete. Please shut down this host and remove the old disk."
						echo "DO NOT DELETE THE OLD DISK UNTIL YOU ARE CERTAIN THE MACHINE BOOTS."
					else
						echo "ERROR: grub-install exited with a non-zero status."
						exit 255
					fi
				else
					echo "ERROR: Non-zero exit status during boot migration."
					exit 255
				fi
			else
				echo "ERROR: Non-zero exit status during vgreduce/pvremove command sequence."
				exit 255
			fi
		else
			echo "ERROR: Non-zero exit status while trying to create physical volume on /dev/sdb2."
			exit 255
		fi
	else
		echo "ERROR: Non-zero exit status while creating partition table on /dev/sdb."
		exit 255
	fi
else
	echo "OK, if you don't want to proceed, we'll get over it."
fi

exit 0
