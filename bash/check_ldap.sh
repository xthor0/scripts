#!/bin/bash

servers="amsterdam.datamark.com ankara201.datamark.ftp beihai.datamark.com bombay201.datamark.ftp boston.datamark.com botswana.datamark-inc.com brussels.datamark.com caracas.datamark.com compton.datamark.com damascus.datamark.com denver.datamark.com devboston.datamark.com devhollywood.datamark.com devlagos.datamark-inc.com devmumbai.datamark-inc.com devseville.datamark.com devseville2.datamark-inc.com devzurich.datamark-inc.com durban.datamark.com edmonds301.datamark-inc.com fortworth201.datamark.ftp fredonia.datamark.com grandcayman101.datamark-inc.com grandcayman102.datamark-inc.com grandcayman201.datamark-inc.com grandcayman202.datamark-inc.com hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp hollywood201.datamark.ftp hollywood202.datamark.ftp hollywood203.datamark.ftp hollywood204.datamark.ftp hollywood205.datamark.ftp hollywood206.datamark.ftp houston101.datamark-inc.com houston201.datamark-inc.com kathmandu.datamark.com koln.datamark.com lagos101.datamark.ftp lagos102.datamark.ftp lagos201.datamark.ftp lagos202.datamark.ftp liverpool.datamark-inc.com manila.datamark-inc.com mesquite.datamark.com modesto.datamark.com moscow.datamark.com mumbai101.datamark.ftp mumbai102.datamark.ftp mumbai201.datamark.ftp mumbai202.datamark.ftp portelizabeth.datamark.com portland101.datamark-inc.com preview.datamark.com qahollywood.datamark.com qaseville.datamark.com qa2dns.datamark.com qa2hollywood.datamark.com qa2seville.datamark.com qaboston.datamark.com qadns.datamark.com qageneva.datamark.com qajerseycity.datamark.com qalagos.datamark-inc.com qamumbai.datamark-inc.com qasmtp.datamark.com qazurich.datamark-inc.com seville101.datamark.ftp seville102.datamark.ftp seville201.datamark.ftp seville202.datamark.ftp stdns.datamark.com sthollywood.datamark.com stlagos.datamark-inc.com stmumbai.datamark-inc.com stseville.datamark.com stzurich.datamark-inc.com suva.datamark.ftp warsaw.datamark.com washingtondc.datamark.com wendover.datamark.com zurich101.datamark-inc.com zurich102.datamark-inc.com zurich201.datamark-inc.com zurich202.datamark-inc.com"

printf "%-50s %s\n" Host Service
echo "======================================================================"
for server in $servers; do
	ping -c1 -W1 -q $server >& /dev/null
	if [ $? -ne 0 ]; then
		printf "%-50s %s\n" $server "HOST DOWN"
		continue
	fi

	ssh $server "
		id=\$(id -u)
		if [ \$id -eq 10000 ]; then
			return=10
		elif [ \$id -eq 10975 ]; then
			return=20
		else
			return=30
		fi
		exit \$return
	" # end SSH session
	retval=$?
	if [ $retval -eq 10 ]; then
		service="LDAP"
	elif [ $retval -eq 20 ]; then
		service="Active Directory"
	else
		service="Local User"
	fi

	# say cheese!
	printf "%-50s %s\n" $server "$service"
done
