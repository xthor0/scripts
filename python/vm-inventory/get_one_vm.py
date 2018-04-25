#!/usr/bin/env python
# VMware vSphere Python SDK
# Copyright (c) 2008-2013 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Stolen from getallvms.py
Get a single VM by name from vCenter, and print out all the info
"""

import atexit
import getpass
import argparse
import pprint

from pyVim import connect
from pyVmomi import vmodl
from pyVmomi import vim

def get_args():
    """ get arguments, duh... """

    parser = argparse.ArgumentParser()
    parser.add_argument('-H', '--host', required=True, help='hostname running vCenter API')
    parser.add_argument('-U', '--user', required=True, help='Username (for vCenter API)')
    parser.add_argument('-p', '--port', type=int, default=443, help='Port for vCenter API (default: 443)')
    parser.add_argument('-N', '--name', required=True, help='Name of VM to display')
    parser.add_argument('-S', '--disable_ssl_verification', help='Disable SSL certificate verification', action="store_true")
    args = parser.parse_args()
    return args

def get_password(host):
    """ prompt for the password (securely!) """

    try:
        prompt="Please enter your password for {}: ".format(host)
        password = getpass.getpass(prompt=prompt)
        return password
    except Exception as error:
        print('ERROR', error)
        exit(255)

def print_vm_info(virtual_machine):
    """
    Print information for a particular virtual machine or recurse into a
    folder with depth protection
    """

    summary = virtual_machine.summary
    print("Name       : ", summary.config.name)
    print("Template   : ", summary.config.template)
    print("Path       : ", summary.config.vmPathName)
    print("Guest      : ", summary.config.guestFullName)
    print("Instance UUID : ", summary.config.instanceUuid)
    print("Bios UUID     : ", summary.config.uuid)
    annotation = summary.config.annotation
    if annotation:
        print("Annotation : ", annotation)
    print("State      : ", summary.runtime.powerState)
    if summary.guest is not None:
        ip_address = summary.guest.ipAddress
        tools_version = summary.guest.toolsStatus
        if tools_version is not None:
            print("VMware-tools: ", tools_version)
        else:
            print("Vmware-tools: None")
        if ip_address:
            print("IP         : ", ip_address)
        else:
            print("IP         : None")
    if summary.runtime.question is not None:
        print("Question  : ", summary.runtime.question.text)
    print("")


def main():
    """
    Simple command-line program for listing the virtual machines on a system.
    """

    args = get_args()
    password = get_password(args.host)

    try:
        if args.disable_ssl_verification:
            service_instance = connect.SmartConnectNoSSL(host=args.host,
                                                         user=args.user,
                                                         pwd=password,
                                                         port=int(args.port))
        else:
            service_instance = connect.SmartConnect(host=args.host,
                                                    user=args.user,
                                                    pwd=password,
                                                    port=int(args.port))

        atexit.register(connect.Disconnect, service_instance)

        content = service_instance.RetrieveContent()

        container = content.rootFolder  # starting point to look into
        viewType = [vim.VirtualMachine]  # object types to look for
        recursive = True  # whether we should look into it recursively
        containerView = content.viewManager.CreateContainerView(
            container, viewType, recursive)

        children = containerView.view
        vminfo = None
        for child in children:
            if child.config.name == args.name:
                # print_vm_info(child)
                vminfo = child.summary
                # pprint.pprint(child.summary)

        if vminfo is None:
            print("No VM found named {}.".format(args.name))
        else:
            pprint.pprint(vminfo)

    except vmodl.MethodFault as error:
        print("Caught vmodl fault : " + error.msg)
        return -1

    return 0


# Start program
if __name__ == "__main__":
    main()
