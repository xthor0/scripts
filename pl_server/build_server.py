#!/usr/bin/env python

import argparse
import ipaddress

# import custom modules
import ipam
import cmdb
import plserver
import pprint

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-t', '--template', required=True, help='Server Template Name')
args = parser.parse_args()

# load a ci server template from SNOW using the template name provided
snow = cmdb.SNOWAPIClient()
snow.load_template(args.template)

# if we got data - make an IPAM request
if snow.subnet is not None:
    ipam = ipam.PHPIpamClient()
    ipam.get_ip(snow.subnet)

    if ipam.ipaddr is not None:
        # get gateway from ipaddress module
        gateway = str(ipaddress.IPv4Network(snow.subnet)[1])

        # new server
        pls = plserver.PLServer()

        # populate info from SNOW
        pls.populate(snow)

        # populate network info
        pls.populate_network(ipam.ipaddr, gateway)

        # generate a name for the server
        pls.generate_server_name()

        if pls.name is not None:
            # print out some info for the user
            print("Building server: {}".format(pls.name))
            print("IP Address: {}".format(ipam.ipaddr))

            # register this IP address with the IPAM server
            ipam.register_ip(pls.name)
            if ipam.apiresponse == "Request Failed":
                print("Unable to register IP address {} with IPAM server -- exiting.".format(ipam.ipaddr))
                exit(255)

            # TODO: at this point a new server CI needs to be built!
            # The following fields should be populated in my API call:
            # Server Name, IP address, environment, and patch group - the latter 2 are REQUIRED
            # CI impact also needs to be specified
            # some of this will have to be specified in the template - it doesn't exist today, Steven will pass to Tony
            snow.create_ci(pls.name, pls.ipaddr)
            if snow.apistatuscode == 201:
                print("Created server CI named {} with sys_id {}".format(pls.name, snow.sys_id))
            else:
                print("Unable to create CI for this server! Exiting...")
                exit(255)

            # build the server!
            pls.build_server(snow.sys_id)

            if pls.deployed is True:
                # the new server is registered in Salt now - grab grain info
                pls.get_server(pls.name)

                # update the CI to include the VMware serial number
                # May require updating when discovery runs, though...
                # TODO: how do I create a relationship to the server template CI?
                snow.update_ci_sn(pls.serialnum)

                # after the server is built, we'll need to update it, reboot it,
                # and then apply the appropriate states...
                pls.apply_cmdb_states()
                if pls.retcode == 0:
                    pls.mark_server_complete()
                    if pls.retcode == 0:
                        print("Deployment of server {} complete!".format(pls.name))
                    else:
                        print("Error marking server {} as completed - check output!")
                        exit(255)
                else:
                    print("Unable to apply salt states from CMDB -- exiting.")
                    exit(255)
            else:
                print("Error deploying server {}".format(pls.name))
                exit(255)
        else:
            print("Unable to generate a name for this server. Exiting.")
            exit(255)
else:
    print("Check the name of the template - does it exist in CMDB?")
    exit(255)
