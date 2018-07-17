#!/usr/bin/env python

import pprint
import salt.cloud
import argparse
import uuid

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-p', '--profile', required=True, help='Server Profile Name')
parser.add_argument('-n', '--name', help='Name for New Server (if omitted will be random)')
parser.add_argument('-g', '--grains', help='Salt grains to assign to new server (in JSON)')
args = parser.parse_args()

# this needs work, and testing
# finish later

# generate a random name for the minion ID
if args.name is None:
    seed = uuid.uuid4().hex
    name = seed[:12]
else:
    name = args.name

print("Server will be named: ".format(name))

# this will control how much information the salt calls below output when building a VM
# this can be commented out if NO input is preferred...
from salt.log.setup import setup_console_logger
setup_console_logger(log_level='info')

client = salt.cloud.CloudClient('/etc/salt/cloud')
spec = {'devices':{'disk':{'Hard disk 2':{'size': 100}}}}

# saved in case I want to set grains here later...
#spec = { 'disk': { 'hard disk 2': {'size': '100'} }
#        'grains': {'salt-cloud-deployed': 'true'}
#        }

print('Building a server!\nName: {}\nSalt-Cloud Profile: {}'.format(name, args.profile))

s = client.profile(args.profile, names=[name], vm_overrides=spec)

# after build, reset log level or we get a bunch of weird errors that aren't really from Salt
setup_console_logger(log_level='error')

try:
    if s[name]['hostname'].startswith(name):
        print("{}: Deployed successfully.".format(name))
    else:
        print("{}: Deployed, but Salt hostname doesn't match name.".format(name))
except KeyError:
    print("{}: Did not deploy successfully.".format(name))

exit
