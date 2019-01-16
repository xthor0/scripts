#!/usr/bin/env python

import pprint
import argparse
import ipam
import csv

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-f', '--filename', help='Tab-delimited file to import', required=True)
args = parser.parse_args()

# instnatiate IPAM client
ipam = ipam.PHPIpamClient()

# load input file
csv = list(csv.reader(open(args.filename, 'rb'), delimiter='\t'))

# test return value
for record in csv:

    ip = record[0]
    hostname = record[1]
    description = record[2]

    print("Processing CSV record :: IP: {}, Hostname: {}, Description: {}".format(ip, hostname, description))
    ipam.get_ip(ip)

    try:
        if ipam.id is not None:
            print("This IP address DOES exist - I'll update it.")
            ipam.update_ip(hostname, description)
    except AttributeError:
        print("This IP address doesn't exist in IPAM, so I will create it.")
        ipam.register_ip(ip, hostname, description)

    # stuff I'll delete later
    '''
    try:
        print("IP registered in IPAM with id {}".format(ipam.id))
        # update existing record
        # ipam.update_ip(hostname, description)
        print("Would run ipam.update_ip at this point...")
    except AttributeError:
        # create new record
        # ipam.register_ip(hostname, description)
        print("Would run ipam.register_ip at this point...")
    '''

    # unset stuff for next run
    try:
        del ipam.id
    except AttributeError:
        print("Continuing.")

    # formatting
    print("--->\n")

# end of script
exit(0)



