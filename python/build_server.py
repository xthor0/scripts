#!/usr/bin/env python

import pprint
import salt.cloud
import argparse
import re

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-n', '--name', help='Name for New Server', required=True)
parser.add_argument('-e', '--env', help='Environment to deploy server to (dev, stage, prod)', required=True)
parser.add_argument('-o', '--role', help='Role name to assign to this server', required=True)
parser.add_argument('-r', '--ram', help='RAM for new VM (in GB) - default 2GB')
parser.add_argument('-c', '--cpu', help='CPU cores - default 1')
parser.add_argument('-d', '--datastore', help='Datastore - defaults to DC1 Tintri Cluster')
parser.add_argument('-i', '--ipaddr', help='IP address - otherwise will default to dev subnet DHCP')
args = parser.parse_args()

# this will control how much information the salt calls below output when building a VM
# this can be commented out if NO input is preferred...
from salt.log.setup import setup_console_logger
setup_console_logger(log_level='info')
client = salt.cloud.CloudClient('/etc/salt/cloud')

# here's a template of how the entire spec can be overridden.
'''
spec = {'memory': self.ram, 'num_cpus': self.core_count, 'datastore': self.vmware_datastore,
        'cluster': self.vmware_cluster,
        'annotation': self.vmware_description, 'folder': self.vmware_folder,
        'devices': {'network': {'Network adapter 1': {'name': self.vmnet,
                                                      'ip': self.ipaddr,
                                                      'subnet_mask': '255.255.255.0',
                                                      'gateway': [self.gateway],
                                                      'switch_type': 'distributed',
                                                      'dvs_switch': 'Data dvSwitch'}},
                    'disk': {'Hard disk 1': {'size': self.disk1,
                                             'thin_provision': 'True'}}},
        'grains': {'salt-cloud-deployed': 'true', 'servertemplateci': self.template,
                   'snow_sys_id': snow_sys_id, 'cmdb-states': self.salt_states,
                   'num_disks': self.number_disks, 'environment': self.environment}
        }
'''

# TODO: we need to add a tag somehow so it can be backed up

# set defaults if not specified as arguments
if args.ram is None:
    ram = '2GB'
else:
    ram = '{}GB'.format(args.ram)

if args.cpu is None:
    cpu = 1
else:
    cpu = args.cpu

if args.datastore is None:
    datastore = 'DC1 Tintri Cluster'
else:
    datastore = args.datastore

# we should be able to determine what subnet mask, gateway, and network label we need depending on the IP address
if args.ipaddr is None:
    # won't override the IP address - profile default I think is guests-dev and DHCP
    spec = {'memory': ram, 'num_cpus': cpu, 'datastore': datastore,
            'grains': {'env': args.env, 'roles': {args.role}}
            }
else:
    dev = re.compile('^10.13')
    stage = re.compile('^10.14')
    prod = re.compile('^10.15')
    if dev.match(args.ipaddr):
        netlabel = "guests-dev"
        gateway = "10.13.0.1"
        cluster = "Development"
    if stage.match(args.ipaddr):
        netlabel = "guests-stage"
        gateway = "10.14.0.1"
        cluster = "Production"
    if prod.match(args.ipaddr):
        netlabel = "guests-prod"
        gateway = "10.15.0.1"
        cluster = "Production"

    # error handling
    try:
        netlabel
    except NameError:
        print("Uh oh - no network label defined... are you sure you specified the exiting.")
        exit(255)

    try:
        gateway
    except NameError:
        print("Gateway is null, oops. Exiting.")
        exit(255)

    spec = {'memory': ram, 'num_cpus': cpu, 'datastore': datastore, 'cluster': cluster,
            'devices': {'network': {'Network adapter 1': {'name': netlabel,
                                                          'ip': args.ipaddr,
                                                          'subnet_mask': '255.255.0.0',
                                                          'gateway': [gateway],
                                                          'switch_type': 'distributed',
                                                          'dvs_switch': 'Data dvSwitch'}
                                    },
                        },
            'grains': {'env': args.env, 'roles': [args.role]}
            }

# tell the user what we're doing
print('Salt-cloud is building a server named {}...'.format(args.name))

# kick off the salt-cloud build
s = client.profile('dc1-centos7', names=[args.name], vm_overrides=spec)

# after build, reset log level or we get a bunch of weird errors that aren't really from Salt
setup_console_logger(log_level='error')

try:
    if s[args.name]['hostname'].startswith(args.name):
        print("{}: Deployed successfully.".format(args.name))
    else:
        print("{}: Deployed, but Salt hostname doesn't match name.".format(args.name))
except KeyError:
    print("{}: Did not deploy successfully. Exiting!".format(args.name))
    exit(255)

# highstate the minion
print("Applying highstate to minion {}, please wait...".format(args.name))
local = salt.client.LocalClient()
retjob = local.cmd(args.name, 'state.highstate', full_return=True)
if retjob[args.name]['retcode'] == 0:
    print("Highstate applied successfully - minion {} is ready to rock!".format(args.name))
else:
    print("Uh oh - better check the Salt logs and see why the highstate didn't apply properly.")
    print("I'm gonna dump out a bunch of debugging info here...")
    pprint.pprint(retjob)

# end of script
