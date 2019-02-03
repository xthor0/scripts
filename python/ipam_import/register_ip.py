#!/usr/bin/env python

import pprint
import argparse
import ipam

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--ipaddr', help='IP address to lookup in IPAM', required=True)
parser.add_argument('-n', '--servername', help='Server name to register', required=True)
parser.add_argument('-d', '--description', help='Description to add to this record', required=True)
args = parser.parse_args()

# instnatiate IPAM client
ipam = ipam.PHPIpamClient()

# get an IP and print out all the info associated with it
ipam.register_ip(args.ipaddr, args.servername, args.description)

ipam.get_ip(args.ipaddr)

pprint.pprint(ipam.apiresponse)
