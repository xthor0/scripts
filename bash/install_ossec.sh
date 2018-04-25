#!/bin/bash

#ossec_agent_src="http://apt1.pgx.local/files/ossec-agent-2.8.tgz"
ossec_agent_src_dir="ossec-hids-2.8"
#ossec_agent_src_url="http://10.50.0.46/"
ossec_agent_src_url="http://apt1.pgx.local/files/"
ossec_agent_archive=ossec-agent-2.8.tgz
ossec_agent_uri=${ossec_agent_src_url}${ossec_agent_archive}

# validate OS version

if [ -x "$(which lsb_release 2>/dev/null)" ]; then
	osName=$(lsb_release -s -i)
	osVer=$(lsb_release -s -r)
else
	if [ -f /etc/redhat-release ]; then
		osName="$(sed 's/release/~/g' /etc/redhat-release | cut -d \~ -f 1 | awk '{ print $1 }')"
		osVer="$(sed 's/release/~/g' /etc/redhat-release | cut -d \~ -f 2 | awk '{ print $1 }')"
	else
		echo "Could not determine OS version. Exiting..."
		exit 255
	fi
fi

# functions
nokey() {
	echo "You must specify the security key for OSSEC on the command-line."
	exit 255
}

# check for key
if [ -z "${1}" ]; then
	nokey
else
	key="${1}"
fi


amiroot() {
	if [ $(id -u) -ne 0 ]; then
		echo "This script must be run as root or with sudo. Exiting..."
		exit 255
	fi
}

ubuntu() {
	amiroot
	echo "Installation routines for Ubuntu"
	
	# check OS version
	case "${osVer}" in 
	12.04)
		ossec_agent_src_dir="ossec-hids-2.8"
		ossec_agent_src_url="http://apt1.pgx.local/files/"
		ossec_agent_archive=ossec-agent-2.8.tgz
		ossec_agent_uri=${ossec_agent_src_url}${ossec_agent_archive}
		;;
	11.04)
		ossec_agent_src_dir="ossec-hids-2.8"
		ossec_agent_src_url="http://apt1.pgx.local/files/"
		ossec_agent_archive=ossec-agent-ubuntu1104-2.8.tgz
		ossec_agent_uri=${ossec_agent_src_url}${ossec_agent_archive}
		;;
	*)
		echo "This server is running Ubuntu ${osVer} - no installation routine."
		exit 255
		;;
	esac

	# is ossec agent already installed?
	if [ -x /var/ossec/bin/manage_agents ]; then
		echo "OSSEC Agent is already installed!"
		exit 255
	fi

	tmpdir=$(mktemp -d)
	cd ${tmpdir}
	if [ $? -eq 0 ]; then
		wget -q ${ossec_agent_uri}
		if [ $? -eq 0 ]; then
			tar zxf ${ossec_agent_archive}
			if [ $? -eq 0 ]; then
				cd ${ossec_agent_src_dir}
				./install.sh
				if [ -d /var/ossec ]; then
					if [ -x /var/ossec/bin/ossec-agentd ]; then
						while [ -z "${key}" ]; do
							echo "Please enter the agent key for this host: "
							read key
						done
						/var/ossec/bin/manage_agents -i ${key}
						service ossec start
					else
						echo "Error - installation was not successful, exiting"
						exit 255
					fi
				else
					echo "Error - installation was not successful, exiting"
					exit 255
				fi

			else
				echo "Error extracting OSSEC agent tarball - exiting"
				exit 255
			fi
		else
			echo "Error retrieving ${ossec_agent_uri} - exiting"
			exit 255
		fi
	else
		echo "Error creating temp directory..."
		exit 255
	fi
	cd /
	rm -rf ${tmpdir}
}

centos() {
	echo "Installation routines for CentOS"
	
	# routines change for centos 5 vs 6
	case "${osVer}" in
		5.*)
			rpms="http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/5/ossec-hids-2.8-45.el5.art.x86_64.rpm http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/5/inotify-tools-3.13-1.el5.rf.x86_64.rpm rpm -Uvh http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/5/ossec-hids-client-2.8-45.el5.art.x86_64.rpm"
			;;
		6.*)
			rpms="http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/6/ossec-hids-2.8-45.el6.art.x86_64.rpm http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/6/ossec-hids-client-2.8-45.el6.art.x86_64.rpm http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/6/inotify-tools-3.13-1.el6.rf.x86_64.rpm http://slcyumrepo01.pgx.local/mrepo/pgx/ossec/6/openssl-1.0.1e-16.el6_5.1.x86_64.rpm"
			;;
		*)
			echo "This server is running CentOS $osVer - unrecognized."
			exit 255
			;;
	esac

	# check to make sure ossec isn't already installed
	if [ -x /var/ossec/bin/manage_client ]; then
		echo "OSSEC agent is already installed!"
		exit 255
	fi

	# do we have wget? I guess you never know...
	if [ -x /usr/bin/wget ]; then
		fetch="wget -q"
	else
		if [ -x /usr/bin/curl ]; then
			fetch="curl -s -O"
		fi
	fi

	if [ -z "$fetch" ]; then
		echo "Can't find wget or curl - exiting."
		exit 255
	fi	

	# create temp directory
	tempdir=$(mktemp -d)

	# begin installation
	pushd ${tempdir}
	for url in ${rpms}; do
		$fetch $url
		if [ $? -ne 0 ]; then
			echo "Error downloading ${url} -- exiting."
			exit 255
		fi
	done

	rpm -Uvh *.rpm
	if [ $? -eq 0 ]; then
		# commented for lab
        #sed -i 's/<server-ip.*server-ip>/<server-ip>10.50.0.50<\/server-ip>/g' /var/ossec/etc/ossec-agent.conf
		sed -i 's/<server-ip.*server-ip>/<server-hostname>ossec-svr.pgx.local<\/server-hostname>/g' /var/ossec/etc/ossec-agent.conf
		if [ $? -eq 0 ]; then
			mv /var/ossec/etc/shared/agent.conf /var/ossec/etc/shared/agent.conf.bak
			if [ $? -eq 0 ]; then
				while [ -z "${key}" ]; do
					echo "Please enter the agent key for this host: "
					read key
				done
				/var/ossec/bin/manage_client -i ${key}
				if [ $? -eq 0 ]; then
					service ossec-hids restart
				else
					echo "Error importing key - exiting!"
					exit 255
				fi
			else
				echo "Error moving agent.conf to agent.conf.bak... exiting"
				exit 255
			fi
		else
			echo "Error running sed command to set server-hostname in config file, exiting"
			exit 255
		fi
	else
		echo "Error installing OSSEC RPMs and dependencies, exiting..."
		exit 255
	fi

	# cleanup
	popd
	rm -rf ${tempdir}

}

unrecognized() {
	echo "UNRECOGNIZED OS -- $osName $osVer"
	exit 255
}

# main
case $osName in
	Ubuntu) 	ubuntu;;
	CentOS) 	centos;;
	RedHat*)	centos;;
	*)		unrecognized;;
esac

exit 0
