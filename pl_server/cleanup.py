#!/usr/bin/env python

import argparse
import pprint

# THIS SHOULD ONLY BE USED BY BEN DURING DEBUGGING.
# it removes IP addresses from IPAM and CIs from SNOW, and even deletes VMs.
# really just makes it easier for him to clean up a mess.


def nuke_ip(ipaddr):
    """ remove an IP address from IPAM """
    import ipam
    ipam = ipam.PHPIpamClient()
    ipam.delete_ip(ipaddr)


def nuke_server(servername):
    """ blast a server from VMware, yo! """
    import plserver
    server = plserver.PLServer()
    server.get_server(servername)
    if server.name is not None:
        server.delete_server()
    else:
        print("Server {} not found".format(servername))


def nuke_ci(servername):
    import cmdb
    cmdb = cmdb.SNOWAPIClient()
    cmdb.get_ci_by_name(servername)
    pprint.pprint(cmdb.apidata)
    if cmdb.sys_id is not None:
        cmdb.delete_ci()
        if cmdb.apistatuscode == 204:
            print("CI named {} with sys_id {} deleted from SNOW".format(cmdb.name, cmdb.sys_id))
        else:
            print("CI named {} could not be deleted!".format(cmdb.name))


# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--ipaddr', help='IP address to remove from IPAM')
parser.add_argument('-s', '--server', help='VM to nuke from VMware *AND* SNOW [[DANGEROUS]]')
args = parser.parse_args()

# we need at LEAST one argument, though all three can be provided
if args.ipaddr is None and args.server is None:
    print("No arguments passed!")
    exit(255)

if args.ipaddr is not None:
    print("Deleting this IP from IPAM: {}".format(args.ipaddr))
    nuke_ip(args.ipaddr)

if args.server is not None:
    print("Deleting this server from both SNOW and VMware: {}".format(args.server))
    nuke_ci(args.server)
    nuke_server(args.server)
