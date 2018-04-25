#!/usr/bin/env python

import argparse
import socket
from ipwhois import IPWhois
import pprint
import csv

parser = argparse.ArgumentParser()
parser.add_argument('-f', '--filename', help='Filename containing IP addresses', required=True)
args = parser.parse_args()

f = open(args.filename)
lines = f.readlines()

counter = 0
csvarr = []
for line in lines:
    ipaddr = line.strip()
    try:
        obj = IPWhois(ipaddr)
        whois = obj.lookup_rdap(depth=1)
        org = whois['asn_description']
        country = whois['asn_country_code']
    except:
        org = "Failed"
        country = "Failed"

    # reverse DNS
    try:
        rdns = socket.gethostbyaddr(ipaddr)
    except:
        rdns = ["Failed"]

    # store it in a dictionary
    result = {'ip': ipaddr, 'org': org, 'country': country,
              'reverse_dns': rdns[0]}

    # output
    print("IP: {} -- Organization: {} -- Country: {}".format(ipaddr, org, country))
    print("Reverse DNS: {}".format(rdns[0]))
    print("---")
    counter = counter + 1
    csvarr.append(result)
    # if counter >= 3:
    #    break

# spit it out
# pprint.pprint(csvarr)

# write CSV
keys = csvarr[0].keys()
with open('/Users/xthor/iplist.csv', 'wb') as output_file:
    dict_writer = csv.DictWriter(output_file, keys)
    dict_writer.writeheader()
    dict_writer.writerows(csvarr)

exit(0)
