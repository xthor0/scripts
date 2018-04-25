#!/bin/bash

# corp servers -- ankara101.datamark.ftp beihai.datamark.com boston.datamark.com botswana.datamark-inc.com brasilia.datamark.com caracas.datamark.com compton.datamark.com damascus.datamark.com denver.datamark.com devboston.datamark.com devhollywood.datamark.com devlagos.datamark-inc.com devmumbai.datamark-inc.com devseville.datamark.com devseville2.datamark-inc.com devzurich.datamark-inc.com fredonia.datamark.com grandcayman101.datamark-inc.com grandcayman102.datamark-inc.com hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp houston101.datamark-inc.com kathmandu.datamark.com koln.datamark.com lagos101.datamark.ftp lagos102.datamark.ftp lasvegas101.datamark.ftp manila.datamark-inc.com mesquite.datamark.com modesto.datamark.com moscow.datamark.com mumbai101.datamark.ftp mumbai102.datamark.ftp portelizabeth.datamark.com portland101.datamark-inc.com preview.datamark.com qa1hollywood.datamark.com qa1seville.datamark.com qa2dns.datamark.com qa2hollywood.datamark.com qa2seville.datamark.com qaboston.datamark.com qadns.datamark.com qageneva.datamark.com qajerseycity.datamark.com qalagos.datamark-inc.com qamumbai.datamark-inc.com qasmtp.datamark.com qazurich.datamark-inc.com seville101.datamark.ftp seville102.datamark.ftp stdns.datamark.com sthollywood.datamark.com stlagos.datamark-inc.com stmumbai.datamark-inc.com stseville.datamark.com stzurich.datamark-inc.com suva.datamark.ftp warsaw.datamark.com washingtondc.datamark.com wendover.datamark.com zurich101.datamark-inc.com zurich102.datamark-inc.com

# switch servers -- ankara201.datamark.ftp bombay201.datamark.ftp brussels.datamark.com durban.datamark.com fortworth201.datamark.ftp grandcayman201.datamark-inc.com grandcayman202.datamark-inc.com hollywood201.datamark.ftp hollywood202.datamark.ftp hollywood203.datamark.ftp hollywood204.datamark.ftp hollywood205.datamark.ftp hollywood206.datamark.ftp houston201.datamark-inc.com lagos201.datamark.ftp lagos202.datamark.ftp lasvegas201.datamark.ftp liverpool.datamark-inc.com mumbai201.datamark.ftp mumbai202.datamark.ftp seville201.datamark.ftp seville202.datamark.ftp zurich201.datamark-inc.com zurich202.datamark-inc.com

servers="ankara101.datamark.ftp beihai.datamark.com boston.datamark.com botswana.datamark-inc.com brasilia.datamark.com caracas.datamark.com compton.datamark.com damascus.datamark.com denver.datamark.com devboston.datamark.com devhollywood.datamark.com devlagos.datamark-inc.com devmumbai.datamark-inc.com devseville.datamark.com devseville2.datamark-inc.com devzurich.datamark-inc.com fredonia.datamark.com grandcayman101.datamark-inc.com grandcayman102.datamark-inc.com hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp houston101.datamark-inc.com kathmandu.datamark.com koln.datamark.com lagos101.datamark.ftp lagos102.datamark.ftp lasvegas101.datamark.ftp manila.datamark-inc.com mesquite.datamark.com modesto.datamark.com moscow.datamark.com mumbai101.datamark.ftp mumbai102.datamark.ftp portelizabeth.datamark.com portland101.datamark-inc.com preview.datamark.com qa1hollywood.datamark.com qa1seville.datamark.com qa2dns.datamark.com qa2hollywood.datamark.com qa2seville.datamark.com qaboston.datamark.com qadns.datamark.com qageneva.datamark.com qajerseycity.datamark.com qalagos.datamark-inc.com qamumbai.datamark-inc.com qasmtp.datamark.com qazurich.datamark-inc.com seville101.datamark.ftp seville102.datamark.ftp stdns.datamark.com sthollywood.datamark.com stlagos.datamark-inc.com stmumbai.datamark-inc.com stseville.datamark.com stzurich.datamark-inc.com suva.datamark.ftp warsaw.datamark.com washingtondc.datamark.com wendover.datamark.com zurich101.datamark-inc.com zurich102.datamark-inc.com"

output="/tmp/vmwaretoolsupgrade_output.txt"

read -s -p "Please type your sudo password: " sudopass
echo

for server in ${servers}; do
	echo "${server}: "
	ssh ${server} "
		# first -- verify sudo password
		echo $sudopass | sudo -S whoami >& $output
		if [ \$? -ne 0 ]; then
			echo \"Password error -- please ensure you typed your sudo password correctly.\"
			exit 255
		fi
	
		# let's not reinvent the wheel -- if this is done, we move on
		rpm -q vmware-tools-esx-nox >> $output 2>&1
		if [ \$? -eq 0 ]; then
			# double-check
			vmware-toolbox-cmd stat sessionid >> $output 2>&1
			if [ \$? -eq 0 ]; then
				echo \"VMware Tools has already been upgraded on this host.\"
				exit 255
			else
				echo \"VMware Tools tests failed -- reinstalling.\"
			fi
		fi
		
		# uninstall vmware-tools-release and vmware-tools stuff
		echo -n \"Removing old VMware Tools packages... \"
		echo $sudopass | sudo -S yum -y remove vmware-tools-release vmware-open-vm-tools\\* >> $output 2>&1
		echo \"Done.\"
		
		# do we have vmware tools with xorg shit installed? if so, we have to kill that shit first
		rpm -qa | grep 'vmware.*xorg' >> $output 2>&1
		if [ \$? -eq 0 ]; then
			echo -n \"Removing vmware tools xorg packages... \"
			rpm -qa | grep 'vmware.*xorg' | xargs sudo rpm -e --noscripts >> $output 2>&1
			echo \"Done.\"
		fi
		
		# make sure ALL vmware crap is GONE
		rpm -qa | grep vmware >> $output 2>&1
		if [ \$? -eq 1 ]; then
			# what version of CentOS are we running?
			version=\`cat /etc/redhat-release | awk '{ print \$3 }' | cut -d . -f 1\`
			arch=\`uname -i\`
			if [ \$arch == \"i386\" ]; then
				arch=\"i686\"
			fi
			
			# fetch the RPM from vmware and install it
			echo -n \"Installing VMware Tools repo package... \"
			echo $sudopass | sudo -S rpm -Uvh http://packages.vmware.com/tools/esx/latest/repos/vmware-tools-repo-RHEL\${version}-9.0.0-2.\${arch}.rpm >> $output 2>&1
			if [ \$? -eq 0 ]; then
				echo \"Done.\"
				echo -n \"Installing VMware Tools updated packages... \"
				echo $sudopass | sudo -S yum -y install vmware-tools-esx-nox >> $output 2>&1
				if [ \$? -eq 0 ]; then
					echo \"Done.\"
					echo \"Verifying installation... \"
					vmware-toolbox-cmd stat sessionid >> $output 2>&1
					if [ \$? -eq 0 ]; then
						echo \"VMware Tools has been upgraded successfully.\"
					else
						echo \"VMware Tools installation could not be verified!\"
					fi
				else
					echo \"VMware tools could not be properly installed!\"
				fi
			else
				echo \"VMware Tools repo RPM could not be properly installed!\"
			fi
		else
			echo \"Previous version of VMware tools could not be removed from the system.\"
		fi
	" # END SSH SESSION
done

exit 0