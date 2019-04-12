#!/usr/bin/env python

import os
import hvac
import argparse
import pprint

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-r', '--roleid', required=True, help='vault role-id', type=str)
parser.add_argument('-s', '--secretid', required=True, help='vault secret-id', type=str)
parser.add_argument('-u', '--url', required=True, help='vault URL', type=str)
parser.add_argument('-k', '--secret', required=True, help='vault secret to read', type=str)
args = parser.parse_args()

client = hvac.Client()
client = hvac.Client(
 url=args.url
)

# authenticate with approle
client.auth_approle(args.roleid, args.secretid)

if client.is_authenticated() == True:
    # client.write('secret/ben', type='pythons', lease='1h')
    # print(client.read('secret/ben'))
    # print(client.read('secret/sub/ben'))
    secret=client.read(args.secret)
    pprint.pprint(secret['data'])
else:
    print('Error authenticating.')
