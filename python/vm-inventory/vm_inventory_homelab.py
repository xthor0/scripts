#!/usr/bin/env python
"""
Python script to pull VM information out of a vCenter instance.
Stolen shamelessly from get_vm_names.py (sample pyvmomi code)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""
from __future__ import print_function
import atexit
from pyVim.connect import SmartConnectNoSSL, Disconnect
from pyVmomi import vim
from tools import cli
import redis
import salt.client

MAX_DEPTH = 10


def setup_args():
    """
    Get standard connection arguments
    """
    parser = cli.build_arg_parser()
    my_args = parser.parse_args()

    return cli.prompt_for_password(my_args)


def vminfo(vm, depth=1):
    """
    Return all info for a particular virtual machine or recurse into a folder
    with depth protection
    """

    # if this is a group it will have children. if it does, recurse into them
    # and then return
    if hasattr(vm, 'childEntity'):
        if depth > MAX_DEPTH:
            return
        vmlist = vm.childEntity
        for child in vmlist:
            vminfo(child, depth+1)
        return

    # an example if we ONLY wanted non-windows VMs...
    #if "windows" in vm.config.guestId:
    #    return
    #else:
    #    return vm.summary
    return vm.summary


def inventory(conn, item, minionid):
    """
    Check the database. See if this record exists. If it does - update. If not - insert.
    """

    # convert the record fed in into a dict with appropriate values
    # the main things we are interested in: VM name, UUID, guestFullName, numCpu, memorySizeMB
    inventory_dict = { 
        "Name":item.config.name,
        "UUID":item.config.uuid,
        "GuestOS":item.config.guestFullName,
        "PowerState":item.runtime.powerState,
        "NumCPU":str(item.config.numCpu).strip(),
        "MemoryMB":str(item.config.memorySizeMB).strip(),
        "ipAddress":item.guest.ipAddress,
        "MinionID":minionid
    }

    #print(inventory_dict)

    # name the record that will be inserted into redis
    keyname = item.config.uuid

    # does the record exist?
    dbitem = conn.hgetall(keyname)
    if dbitem:
        #print("Name: {} :: UUID: {}".format(dbitem['Name'], dbitem['UUID']))
        unmatched_item = set(dbitem.items()) ^ set(inventory_dict.items())
        if len(unmatched_item) == 0: # should be 0
            print("Record {} is correct in database.".format(keyname))
        else:
            print(len(unmatched_item))
            print("Record {} needs to be updated!".format(keyname))
            attrs = [ "Name", "GuestOS", "NumCPU", "MemoryMB" ]
            for attr in attrs:
                if dbitem[attr] != inventory_dict[attr]:
                    print("{}: {} does not match! DB: {} -- VMware: {}".format(keyname, attr, dbitem[attr], inventory_dict[attr]))
                else:
                    print("{}: {} matches DB".format(keyname, attr))
    else:
        # insert the record
        conn.hmset(keyname, inventory_dict)
        print("Record created in redis: {}".format(keyname))

def getminionid(ipaddr):
    """
    connect to local Salt master and see if we can find this minion
    """

    local = salt.client.LocalClient()
    val = local.cmd(ipaddr, 'test.ping', tgt_type='ipcidr')

    print(val.keys)
    return val


def main():
    """
    Simple command-line program for listing the virtual machines on a host.
    """

    args = setup_args()
    si = None
    try:
        si = SmartConnectNoSSL(host=args.host, user=args.user, pwd=args.password, port=int(args.port))
        atexit.register(Disconnect, si)
    except vim.fault.InvalidLogin:
        raise SystemExit("Unable to connect to host with supplied credentials.")

    results = []
    content = si.RetrieveContent()
    for child in content.rootFolder.childEntity:
        if hasattr(child, 'vmFolder'):
            datacenter = child
            vmfolder = datacenter.vmFolder
            vmlist = vmfolder.childEntity
            for vm in vmlist:
                vminf = vminfo(vm)
                if vminf is None:
                    continue
                else:
                    results.append(vminf)

    # connect to local Redis instance
    # using the cli import, I'm not sure how to specify this on command-line...
    # this will have to be manually modified for each environment
    r = redis.Redis(host='redis.xthorsworld.com', password='g0fuck0ff')

    # process results
    for item in results:
        #print("VM: {} :: UUID: {}".format(item.config.name, item.config.uuid))
        #inventory(r, item)
        minionid = getminionid(item.guest.ipAddress)
        #inventory(r, item, minionid)


# Start program
if __name__ == "__main__":
    main()

