#!/usr/bin/env python

import pprint
import argparse
import ipam
import csv

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--ipaddr', help='IP address to lookup in IPAM', required=True)
args = parser.parse_args()

# instnatiate IPAM client
ipam = ipam.PHPIpamClient()

# get an IP and print out all the info associated with it
ipam.get_ip(args.ipaddr)
if ipam.id is not None:
    pprint.pprint(ipam.apiresponse)

