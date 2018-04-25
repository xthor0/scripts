#!/bin/bash

cat iplist1 | while read ip; do
  rdns=$(host ${ip} | awk '{ print $5 }' | tr \\n ' ')
  # parse whois info
  whois ${ip} > /tmp/whois.out
  org=$(grep ^Organization /tmp/whois.out | awk ' { print $2 }' | tr -d ,)
  country=$(grep ^Country /tmp/whois.out | awk '{ print $2 }' | tr -d ,)
  echo "${ip},${org},${country},${rdns}"
done
