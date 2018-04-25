#!/usr/bin/expect

set timeout 10

# logging
set ::logfile [open /Users/xthor/ssh_test.txt a]


# begin loop
foreach host { beihai.datamark.com compton.datamark.com hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp kathmandu.datamark.com kayoa101.datamark-inc.com kelang101.datamark-inc.com manila.datamark-inc.com mesquite.datamark.com milan101.datamark-inc.com modesto.datamark.com qaseville101.datamark-inc.com thamel.datamark-inc.com sepang101.datamark-inc.com sepang102.datamark-inc.com stmumbai.datamark-inc.com stsepang.datamark-inc.com devmumbai.datamark-inc.com mumbai101.datamark.ftp mumbai102.datamark.ftp qamumbai.datamark-inc.com devsepang.datamark-inc.com qasepang.datamark-inc.com cleveland101.datamark-inc.com devbangkok.datamark-inc.com koln.datamark.com moscow.datamark.com qahollywood.datamark.com qa2hollywood.datamark.com amsterdam.datamark.com boston.datamark.com botswana.datamark-inc.com cairo101.datamark-inc.com denver.datamark.com devamartin.datamark-inc.com devblewis.datamark-inc.com devboston.datamark.com devccolvell.datamark-inc.com devhollywood.datamark.com devseville.datamark.com devseville2.datamark-inc.com duluth101.datamark-inc.com fredonia.datamark.com fresno101.datamark-inc.com houston101.datamark-inc.com portelizabeth.datamark.com portland101.datamark-inc.com preview.datamark.com qaseville.datamark.com qa2seville.datamark.com qaboston.datamark.com qajerseycity.datamark.com qasmtp.datamark.com reno101.datamark-inc.com saltlakecity101.datamark-inc.com seville101.datamark.ftp seville102.datamark.ftp stdns.datamark.com sthollywood.datamark.com stseville.datamark.com warsaw.datamark.com washingtondc.datamark.com watts.datamark.com wendover.datamark.com } {
	spawn ssh bbrown@$host
	#expect_after eof { exit 0 }

	# login
	expect {
		timeout { puts $::logfile "$host ==> Timed out while waiting for login prompt"; continue }
		eof { puts $::logfile "$host ==> EOF waiting for ssh output"; continue }
		"assword: "
	}

	send "W1ll1@mR0b3rtBr0wn\r"

	expect {
		timeout { puts $::logfile "$host ==> Timed out while waiting for login prompt"; continue }
		eof { puts $::logfile "$host ==> SSH session immediately closed"; continue }
		"*\$ "
	}

	# logout
	send "logout\r"
	puts $::logfile "$host ==> SSH access for bbrown still active";
}

# end
exit
