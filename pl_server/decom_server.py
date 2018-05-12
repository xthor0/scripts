#!/usr/bin/env python

import argparse
import pprint

# import custom modules
import ipam
import cmdb
import plserver

# TODO: add arguments to cool down a server - we need a process for this
# if we shut down a server, and rename it, Salt will get angry and commands take a long time as they wait for downed
# minions

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-s', '--server', required=True, help='Short name of server to decom (e.g. LAB-MINION01)')
args = parser.parse_args()

# new PL server instance
server = plserver.PLServer()
server.get_server(args.server)

if server.name is not None:
    # look up the CI in SNOW
    cmdb = cmdb.SNOWAPIClient()
    cmdb.get_ci_by_name(server.name)
    if server.serialnum == cmdb.serialnum:
        # delete CI from SNOW
        cmdb.delete_ci()
        if cmdb.apistatuscode == 204:
            print("CI named {} with sys_id {} deleted from SNOW".format(cmdb.name, cmdb.sys_id))
        else:
            print("CI named {} could not be deleted!".format(cmdb.name))
    else:
        print("The CI pulled from SNOW does not match the minion grain info!")
        print("CMDB CI sys_id: {}".format(cmdb.sys_id))
        print("Minion serial number: {}".format(server.serialnum))

    # remove the record from IPAM
    ipam = ipam.PHPIpamClient()
    ipam.delete_ip(server.ipaddr)

    # here is the placeholder for running 'realm leave --unattended -r'
    # remove_server_from_domain

    # remove the server from Salt
    server.delete_server()
else:
    print("Unable to find a minion named {}. Exiting.".format(args.server))
    exit(255)

# TODO: there are more things!
# remove the computer object from AD - I think this will be as simple as a Salt command to tell the minion to run
# 'realm leave' (but, this should be tested)
# update: need to test 'realm leave -r', but I need to build it into a state so I can use the pillar :)

# some old notes I may still need if 'realm leave --unattended -r' doesn't do the cleanup properly:
# I tested this. 'realm leave' does not delete the computer object from AD. I think I'll probably have to write a
# salt call into one of the domain controllers, which will execute Powershell code (or something) to do the following:
# 1. delete the computer object
# 2. delete the forward DNS lookup
# 3. delete the PTR from DNS
# life would be easier if we were running Linux DNS servers... sigh

# in prod, we'll need to remove the server from Zabbix - need to figure out python to do that
