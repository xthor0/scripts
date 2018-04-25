#!/bin/bash

for domain in enroll.explorewalden.com enroll.waldenmgt.com enroll.waldennurse.com gain.explorewalden.com gain.waldenhealth.com gain.waldennurse.com goals.explorewalden.com goals.waldenmgt.com goals.waldennurse.com goal.waldennurse.com join.explorewalden.com join.waldenhealth.com join.waldenmgt.com join.waldennurse.com learn.explorewalden.com learn.waldennurse.com m.discoverwalden.com m.waldenmgt.com plan.waldenmgt.com progress.explorewalden.com success.waldennurse.com ; do

redirect="`echo "GET / HTTP/1.1
host: ${domain}
" | nc ${domain} 80 | grep 'location:' | cut -d \/ -f 3`"

title="`echo "GET / HTTP/1.1
host: ${domain}
" | nc ${domain} 80 | grep '<title'`"

redirectip="`dig +short ${redirect}`"

#echo "${domain} redirects to ${redirect}, which is pointed to ${redirectip}."
echo ${domain}
echo ${title}
#echo ${redirect}
#echo ${redirectip}

done

exit 0
