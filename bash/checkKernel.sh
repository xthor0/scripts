#!/bin/bash

servers="amsterdam.datamark.com ankara101.datamark.ftp ankara201.datamark.ftp beihai.datamark.com bombay201.datamark.ftp boston.datamark.com brasilia.datamark.com brussels.datamark.com caracas.datamark.com compton.datamark.com damascus.datamark.com denver.datamark.com devboston.datamark.com devgeneva.datamark.com devhollywood.datamark.com devlisbon.datamark-inc.com devseville.datamark.com devseville2.datamark-inc.com durban.datamark.com edmonds.datamark.com fortworth201.datamark.ftp fredonia.datamark.com grandcayman101.datamark-inc.com grandcayman102.datamark-inc.com grandcayman201.datamark-inc.com grandcayman202.datamark-inc.com greenbrier.datamark.com hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp hollywood201.datamark.ftp hollywood202.datamark.ftp hollywood203.datamark.ftp hollywood204.datamark.ftp hollywood205.datamark.ftp hollywood206.datamark.ftp houston101.datamark-inc.com houston201.datamark-inc.com koln.datamark.com lasvegas101.datamark.ftp lasvegas201.datamark.ftp liverpool.datamark.com mesquite.datamark.com modesto.datamark.com qaseville.datamark.com qa2seville.datamark.com qaboston.datamark.com seville101.datamark.ftp seville102.datamark.ftp seville201.datamark.ftp seville202.datamark.ftp stseville.datamark.com"

out="$HOME/servers.csv"

for server in $servers; do
	echo -n "${server},"
	ssh $server "echo -n \`uname -r\`,"
	echo
done > $out
