#!/usr/bin/expect

set timeout 10
#set hostname [lindex $argv 0]
set oldpass [lindex $argv 0]
set newpass [lindex $argv 1]

if {[llength $argv] == 0} {
  send_user "Usage: scriptname oldpassword newpassword\n"
  exit 255
}

# logging
set ::logfile [open /tmp/log.txt a]


# begin loop
# all hosts -- amsterdam.datamark.com ankara201.datamark.ftp beihai.datamark.com bombay201.datamark.ftp boston.datamark.com botswana.datamark-inc.com brasilia.datamark.com brussels.datamark.com caracas.datamark.com compton.datamark.com damascus.datamark.com denver.datamark.com devboston.datamark.com devhollywood.datamark.com devlagos.datamark-inc.com devmumbai.datamark-inc.com devseville.datamark.com devseville2.datamark-inc.com devzurich.datamark-inc.com durban.datamark.com edmonds301.datamark-inc.com fortworth201.datamark.ftp fredonia.datamark.com grandcayman101.datamark-inc.com grandcayman102.datamark-inc.com grandcayman201.datamark-inc.com grandcayman202.datamark-inc.com hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp hollywood201.datamark.ftp hollywood202.datamark.ftp hollywood203.datamark.ftp hollywood204.datamark.ftp hollywood205.datamark.ftp hollywood206.datamark.ftp houston101.datamark-inc.com houston201.datamark-inc.com kathmandu.datamark.com koln.datamark.com lagos101.datamark.ftp lagos102.datamark.ftp lagos201.datamark.ftp lagos202.datamark.ftp liverpool.datamark-inc.com manila.datamark-inc.com mesquite.datamark.com modesto.datamark.com moscow.datamark.com mumbai101.datamark.ftp mumbai102.datamark.ftp mumbai201.datamark.ftp mumbai202.datamark.ftp portelizabeth.datamark.com portland101.datamark-inc.com preview.datamark.com qahollywood.datamark.com qaseville.datamark.com qa2dns.datamark.com qa2hollywood.datamark.com qa2seville.datamark.com qaboston.datamark.com qadns.datamark.com qageneva.datamark.com qajerseycity.datamark.com qalagos.datamark-inc.com qamumbai.datamark-inc.com qasmtp.datamark.com qazurich.datamark-inc.com seville101.datamark.ftp seville102.datamark.ftp seville201.datamark.ftp seville202.datamark.ftp stdns.datamark.com sthollywood.datamark.com stlagos.datamark-inc.com stmumbai.datamark-inc.com stseville.datamark.com stzurich.datamark-inc.com suva.datamark.ftp warsaw.datamark.com washingtondc.datamark.com wendover.datamark.com zurich101.datamark-inc.com zurich102.datamark-inc.com zurich201.datamark-inc.com zurich202.datamark-inc.com
foreach host { ankara201.datamark.ftp beihai.datamark.com bombay201.datamark.ftp denver.datamark.com durban.datamark.com fortworth201.datamark.ftp hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp kathmandu.datamark.com manila.datamark-inc.com moscow.datamark.com mumbai101.datamark.ftp mumbai102.datamark.ftp mumbai201.datamark.ftp mumbai202.datamark.ftp portelizabeth.datamark.com preview.datamark.com qajerseycity.datamark.com qamumbai.datamark-inc.com qasmtp.datamark.com qazurich.datamark-inc.com seville101.datamark.ftp seville102.datamark.ftp stdns.datamark.com stmumbai.datamark-inc.com stseville.datamark.com suva.datamark.ftp warsaw.datamark.com wendover.datamark.com bangkok201.datamark.ftp } {
	spawn ssh root@$host
	#expect_after eof { exit 0 }

	## interact with SSH
	# log in to server as root
	expect {
	  timeout { send_user "**> Failed to get password prompt for $host\n"; puts $::logfile "$host -- no password prompt"; continue }
	  eof { send_user "**> SSH failure for $host\n"; puts $::logfile "$host -- premature eof"; continue }
	  "*assword:"
	}

	send "$oldpass\r"
	expect {
		timeout { send_user "**> No response after password sent.\n"; puts $::logfile "$host -- no response"; continue }
		"Permission denied, please try again.*assword:" {
			send_user "**> Old password doesn't work, let's try the new password...\n"
			send "$newpass\r"
			expect {
				timeout { send_user "**> Timeout sending old password.\n"; puts $::logfile "$host -- bad root password"; continue }
				"*?\# " { 
					send_user "**> New password worked -- password has already been changed on $host.\n"
					send "logout\r"
					puts $::logfile "$host -- verified"
					continue
				}
			}
		}
		"*?\# "
	}
		
	# change password
	send "passwd\r"
	expect {
		timeout {
			send_user "**> Timed out waiting for prompt to change password.\n"
			puts $::logfile "$host -- timeout after login"
			continue
		}
		"New*password: "
	}

	send "$newpass\r"
	expect "Retype new*password: "
	send "$newpass\r"

	# was it successful?
	expect { 
		timeout { send_user "**> Password change unsuccessful on $host.\r"; puts $::logfile "$host -- timeout changing password"; continue }
		"*passwd: all authentication tokens updated successfully.\r"
	}

	# logout
	expect "?*\# "
	send "logout\r"
	send_user "**> Password change successful on $host.\n"
	puts $::logfile "$host -- completed"
}

# end
close $::logfile
exit
