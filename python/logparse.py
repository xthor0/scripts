#!/usr/bin/env python3

import pprint
import argparse
import requests
import re
import time

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--ip', help='get most frequent source IPs and list top 10', action='store_true')
parser.add_argument('-e', '--endpoints', help='Aggregate the most common request endpoints and list the top 10')
parser.add_argument('-5', '--5xx', help='Identify any 5xx status codes, and aggregate on the client IP + endpoint')
parser.add_argument('-4', '--4xx', help='Identify any 4xx status codes and determine the client IP, request endpoint'
                                        ' they were attempting to hit, and represent a count of each IP/request pair'
                                        ' - print a sorted list by count via stdout - all results'
                                        ' should be represented')
args = parser.parse_args()

# run a timer - let's measure how long this is taking
start = time.time()

# load log file
target_url = "https://raw.githubusercontent.com/elastic/examples/master/Common%20Data%20Formats/apache_logs/apache_logs"
response = requests.get(target_url)
data = response.iter_lines()

end = time.time()
elapsed = end - start
print('Downloaded log file in {} seconds'.format(elapsed))

if args.ip:
    print("Parse by IP")
    # grab all source IPs into a set
    print('Parsing log file for unique IP addresses...')
    start = time.time()
    ipaddrs = set()
    for line in data:
        ip = line.split()
        ipaddrs.add(ip[0].decode('utf-8'))
    end = time.time()
    elapsed = end - start
    print('Done in {} seconds'.format(elapsed))

    # count occurrences of IP address in the log, and store it in list
    print('Counting IP address occurrences...')
    start = time.time()
    iphits = []
    for ip in ipaddrs:
        # searchstring = ''.join(data)
        # ipfind = re.findall('^{}'.format(ip), searchstring)
        # dict = {len(ipfind), ip}
        # iphits.append(dict)
        regex = re.compile('^{}'.format(ip))
        count = 0
        for line in response.iter_lines():
            if regex.match(line.decode('utf-8')):
                count = count + 1
        iphits.append({'ip' : ip, 'count' : count})
        # print('{0:<3} {1:>12}'.format(count, ip))
    end = time.time()
    elapsed = end - start
    print('Done in {} seconds'.format(elapsed))

    # spit it out
    pprint.pprint(iphits)
    print(len(iphits))

# debugging
# pprint.pprint(args)
