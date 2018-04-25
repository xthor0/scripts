#!/bin/bash

#servers="ankara101 ankara201 beihai bombay201 boston brasilia brussels caracas compton damascus daqing denver devboston devgeneva devhollywood Devlisbon devseville durban edmonds fortworth201 fredonia grandcayman101 grandcayman102 grandcayman201 grandcayman202 greenbrier Hollywood101 Hollywood102 Hollywood103 Hollywood104 Hollywood105 Hollywood201 Hollywood202 Hollywood203 Hollywood204 Hollywood205 Hollywood206 houston101 houston201 koln lasvegas101 lasvegas201 liverpool mesquite modesto moscow portelizabeth preview qahollywood qaseville qa2dns qa2hollywood qa2seville qaboston qadns qageneva qajerseycity qasmtp seville101 seville102 Seville201 Seville202 snowville stdns sthollywood stseville suva warsaw washingtondc wendover"

#servers="taipei101 taipei201 beijing berlin deadhorse devfrankfurt devshanghai dusseldorf florence101 florence102 frankfurt geneva101 greenriver hamburg istanbul lausanne lucerne munich nuremberg ottawa perth101 qashanghai redmond sandhollow stlouis101 stshanghai geneva201 perth201 shanghai stlouis201 stuttgart anchorage annapolis101 annapolis102 antelope athens101 canyonlands capetown101 columbus101 devflorence devmunich franklin huzhou johannesburg101 kansascity101 lddevvm manti moosejaw newark newyork normandy101 palisade rps starvation timpanogos westpoint101 westpoint102 zurich annapolis201 annapolis202 hamburg201 jerseycity johannesburg201 manti201 Melbourne munich201 NewYork201 normandy201 westpoint201 westpoint203" 

servers="berkeley
cupertino
paloalto
paloalto201
paloalto202
paloalto203
santaclara
anchorage
huzhou
johannesburg101
manti
moosejaw
newark
newyork
normandy101
hamburg201
jerseycity
Melbourne"

for server in $servers; do
	found=0
	for domain in datamark.com datamark-inc.com datamark.ftp; do
		result=$(dig $server.$domain +short)
		if [ -n "$result" ]; then
			if [ "$result" != "10.2.1.200" ]; then
				if [ "$result" != "10.5.0.200" ]; then
					found=1
					host=$server.$domain
					break
				fi
			fi
		fi
	done
	
	#echo "$host --> $result"
	if [ $found -eq 1 ]; then
		echo $host | tr [:upper:] [:lower:]
	else
		echo "Could not find: $server"
	fi
done
