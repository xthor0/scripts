#!/bin/bash

servers="
ankara101.datamark.ftp
ankara201.datamark.ftp
beihai.datamark.com
bombay201.datamark.ftp
boston.datamark.com
brasilia.datamark.com
brussels.datamark.com
caracas.datamark.com
compton.datamark.com
damascus.datamark.com
daqing.datamark.ftp
denver.datamark.com
devboston.datamark.com
devgeneva.datamark.com
devhollywood.datamark.com
devlisbon.datamark-inc.com
devseville.datamark.com
durban.datamark.com
edmonds.datamark.com
fortworth201.datamark.ftp
fredonia.datamark.com
grandcayman101.datamark-inc.com
grandcayman102.datamark-inc.com
grandcayman201.datamark-inc.com
grandcayman202.datamark-inc.com
greenbrier.datamark.com
hollywood101.datamark.ftp
hollywood102.datamark.ftp
hollywood103.datamark.ftp
hollywood104.datamark.ftp
hollywood105.datamark.ftp
hollywood201.datamark.ftp
hollywood202.datamark.ftp
hollywood203.datamark.ftp
hollywood204.datamark.ftp
hollywood205.datamark.ftp
hollywood206.datamark.ftp
houston101.datamark-inc.com
houston201.datamark-inc.com
koln.datamark.com
lasvegas101.datamark.ftp
lasvegas201.datamark.ftp
liverpool.datamark.com
mesquite.datamark.com
modesto.datamark.com
moscow.datamark.com
portelizabeth.datamark.com
preview.datamark.com
qahollywood.datamark.com
qaseville.datamark.com
qa2dns.datamark.com
qa2hollywood.datamark.com
qa2seville.datamark.com
qaboston.datamark.com
qadns.datamark.com
qageneva.datamark.com
qajerseycity.datamark.com
qasmtp.datamark.com
seville101.datamark.ftp
seville102.datamark.ftp
seville201.datamark.ftp
seville202.datamark.ftp
snowville.datamark-inc.com
stdns.datamark.com
sthollywood.datamark.com
stseville.datamark.com
suva.datamark.ftp
warsaw.datamark.com
washingtondc.datamark.com
wendover.datamark.com"


# parse the output better here
for server in $servers; do
	offset=$(/usr/lib/nagios/plugins/check_ntp_time -H $server | awk '{ print $4 }')
	printf "%-40s %20s\n" $server $offset
done

exit 0
