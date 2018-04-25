#!/usr/bin/expect

set timeout 120
set rootpass [lindex $argv 0]

if {[llength $argv] == 0} {
  send_user "Usage: scriptname rootpassword\n"
  exit 255
}

proc log_exit {msg} {
	set ::logfile [open /tmp/salt_deploy_log.txt a]
	puts stderr $msg
	puts $::logfile $msg
}

# begin loop
foreach host {
watts.datamark.com
} {
	spawn ssh root@$host
	#expect_after eof { exit 0 }

	## interact with SSH
	# log in to server as root
	expect {
	  timeout { log_exit "**> Failed to get password prompt for $host\n"; continue }
	  eof { log_exit "**> SSH failure for $host\n"; continue }
	  "Are you sure you want to continue connecting (yes/no)? " {
		send "yes\r"
		sleep 5
	  }
	  "*assword:"
	}

	send "$rootpass\r"
	expect {
		timeout { log_exit "**> $host: No response after password sent.\n"; continue }
		"Permission denied, please try again.*assword:" {
			# if we can't log in the root password is WRONG
			log_exit "**> Unable to log in to $host\n"
			continue
		}
		"*?\# "
	}
		
	# install salt
	send "yum clean all && yum -y -q install salt-minion\r"
	expect {
		timeout { log_exit "**> $host: Timeout installing salt! <**\n"; continue }
		"Package salt-minion* already installed and latest version" {
			log_exit "Salt minion already installed and configured on $host"
			continue
		}
		"?\# "
	}

	# insert master configuration
	send "echo \"master: 10.0.0.121\" >> /etc/salt/minion\r"
	expect {
		timeout { log_exit "**> $host: Timeout inserting master config to /etc/salt/minion <**\n"; continue }
		"?\# "
	}

	# start salt minion
	send "/etc/init.d/salt-minion start\r"

	# logout
	expect "?*\# "
	send "logout\r"
	log_exit "**> Salt minion deployed successfully on $host.\n"
}

# end
close $::logfile
exit
