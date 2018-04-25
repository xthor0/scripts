#!/usr/bin/env python

import argparse
import getpass
import pprint
import atexit

from pyVim import connect
from pyVmomi import vmodl
from pyVmomi import vim


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


def get_vmware_inventory(hostname, username, password, disablesslverification, port):
    """
    Get all VMs from vCenter that are NOT identified as Linux guests
    """

    try:
        if disablesslverification is True:
            service_instance = connect.SmartConnectNoSSL(host=hostname,
                                                         user=username,
                                                         pwd=password,
                                                         port=int(port))
        else:
            service_instance = connect.SmartConnect(host=hostname,
                                                    user=username,
                                                    pwd=password,
                                                    port=int(port))

        atexit.register(connect.Disconnect, service_instance)

        content = service_instance.RetrieveContent()

        container = content.rootFolder  # starting point to look into
        viewType = [vim.VirtualMachine]  # object types to look for
        recursive = True  # whether we should look into it recursively
        containerView = content.viewManager.CreateContainerView(
            container, viewType, recursive)

        children = containerView.view
        vminfo = []
        for child in children:
            if "windows" not in child.summary.config.guestId:
                vminfo.append(child.summary)
        return vminfo

    except vmodl.MethodFault as error:
        print("Caught vmodl fault : " + error.msg)
        return -1


def main():
    # get arguments from command-line
    parser = argparse.ArgumentParser()
    parser.add_argument('-H', '--hostname', required=True, help='hostname of vCenter server')
    parser.add_argument('-u', '--username', required=True, help='username for vCenter server')
    parser.add_argument('-S', '--disable_ssl_verification', action='store_true', help="Disable SSL certificate verification")
    parser.add_argument('-p', '--port', type=int, default=443, help="Port (default: 443)")
    args = parser.parse_args()

    password = get_password(args.hostname)
    results = get_vmware_inventory(args.hostname, args.username, password, args.disable_ssl_verification, args.port)

    pprint.pprint(results)


# Start program
if __name__ == "__main__":
    main()
