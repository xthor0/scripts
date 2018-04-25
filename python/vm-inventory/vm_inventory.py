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
# import redis
import re
import argparse
import getpass
import requests
import pprint
import requests.packages.urllib3
import socket
import MySQLdb
from datetime import datetime

MAX_DEPTH = 10


def getpassword(resource):
    """ get the password to authenticate with in a secure fashion. """
    try:
        prompt = "Please enter your password for {}: ".format(resource)
        password = getpass.getpass(prompt=prompt)
        return password
    except Exception as error:
        print('ERROR', error)
        exit(255)


def setup_args():
    """
    Get standard connection arguments
    this has been modified to use regular ol' argparse instead of tools.cli
    """

    parser = argparse.ArgumentParser()
    parser.add_argument('-u', '--saltuser', required=True, help='Salt API username')
    parser.add_argument('-H', '--salthost', required=True, help='hostname running Salt API')
    parser.add_argument('-V', '--vcenterhost', required=True, help='hostname running vCenter API')
    parser.add_argument('-n', '--vcenteruser', required=True, help='Username (for vCenter API)')
    args = parser.parse_args()

    return args


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
            vminfo(child, depth + 1)
        return

    # an example if we ONLY wanted non-windows VMs...
    # if "windows" in vm.config.guestId:
    #    return
    # else:
    #    return vm.summary
    return vm.summary


def inventory(vmware, salt, lastupdate):
    """
    combine the inputs as a single, awesome dictionary
    """

    # I'm being extra paranoid here - but I want to make sure the VMware UUID matches the Salt serialnumber.
    # we need to do some string conversion before we can do that, though.

    vmware_uuid = re.sub('-', '', vmware.config.uuid)
    if salt is not None:
        salt_uuid = re.sub('^VMware-', '', salt['serialnumber'])
        salt_uuid = re.sub('-', '', salt_uuid)
        salt_uuid = re.sub(' ', '', salt_uuid)

        if vmware_uuid == salt_uuid:
            minionid = str(salt['id'])
            if str(salt['kernel']) == "Linux":
                guestos = str(salt['oscodename'])
            else:
                guestos = str(salt['osfullname'])
            hostname = str(salt['fqdn'])
        else:
            return False
    else:
        minionid = "None"
        guestos = vmware.config.guestFullName
        if vmware.guest.hostName is None:
            hostname = "None"
        else:
            hostname = vmware.guest.hostName

    # convert the vmware record fed in into a dict with appropriate values
    # the main things we are interested in: VM name, UUID, guestFullName, numCpu, memorySizeMB, and ipAddr
    inventory_dict = {
        "VMName": vmware.config.name,
        "UUID": vmware.config.uuid,
        "GuestOS": guestos,
        "PowerState": vmware.runtime.powerState,
        "NumCPU": str(vmware.config.numCpu).strip(),
        "MemoryMB": str(vmware.config.memorySizeMB).strip(),
        "HostName": hostname,
        "ipAddr": str(vmware.guest.ipAddress).strip(),
        "vmwareToolsStatus": str(vmware.guest.toolsStatus),
        "minionid": minionid,
        "lastUpdate": lastupdate
    }

    return inventory_dict


# not used - remove?
def old_inventory(conn, item):
    """
    Check the database. See if this record exists. If it does - update. If not - insert.
    """

    # we need to convert the UUID to be consistent with what we're storing from Salt
    uuid = re.sub('-', '', item.config.uuid)

    # convert the record fed in into a dict with appropriate values
    # the main things we are interested in: VM name, UUID, guestFullName, numCpu, memorySizeMB
    inventory_dict = {
        "Name": item.config.name,
        "UUID": uuid,
        "GuestOS": item.config.guestFullName,
        "PowerState": item.runtime.powerState,
        "NumCPU": str(item.config.numCpu).strip(),
        "MemoryMB": str(item.config.memorySizeMB).strip(),
        "ipAddr": str(item.guest.ipAddress)
    }

    # print(inventory_dict)

    # name the record that will be inserted into redis
    keyname = item.config.uuid

    # does the record exist?
    dbitem = conn.hgetall(keyname)
    if dbitem:
        # print("Name: {} :: UUID: {}".format(dbitem['Name'], dbitem['UUID']))
        unmatched_item = set(dbitem.items()) ^ set(inventory_dict.items())
        if len(unmatched_item) == 0:  # should be 0
            print("Record {} is correct in database.".format(keyname))
        else:
            print(len(unmatched_item))
            print("Record {} needs to be updated!".format(keyname))
            attrs = ["Name", "GuestOS", "NumCPU", "MemoryMB"]
            for attr in attrs:
                if dbitem[attr] != inventory_dict[attr]:
                    print("{}: {} does not match! DB: {} -- VMware: {}".format(keyname, attr, dbitem[attr],
                                                                               inventory_dict[attr]))
                else:
                    print("{}: {} matches DB".format(keyname, attr))
    else:
        # insert the record
        conn.hmset(keyname, inventory_dict)
        print("Record created in redis: {}".format(keyname))


def salt_api_login(url, username, password):
    """ establish a session with the Salt API server """

    session = requests.Session()
    # session.verify = False

    # when logging in, hit /login instead of just url
    loginurl = "{}/{}".format(url, "login/")

    post = session.post(loginurl, json={
        'username': username,
        'password': password,
        'eauth': 'pam',
    })

    result = {"post": post, "session": session}
    return result


def salt_api_cmd(url, conn, target, cmd, saltargs):
    """
    Return results of a command against a Salt API
    """

    # use existing authenticated session
    session = conn['session']

    if saltargs:
        postdata = [{'client': 'local', 'tgt': target, 'fun': cmd, 'arg': saltargs}]
    else:
        postdata = [{'client': 'local', 'tgt': target, 'fun': cmd}]

    resp = session.post(url, json=postdata)

    jsonobj = resp.json()['return']

    # check for null result (actually: a list with a single empty dict)
    if (len(jsonobj[0])) == 0:
        return None
    else:
        return jsonobj[0].values()[0]


def salt_api_minion_id(url, conn, target):
    """
    Returns the Salt minion ID for a given IP address.
    """

    # use existing authenticated session
    session = conn['session']
    post = conn['post']

    # make sure the session was authenticated
    if post.status_code != 200:
        return None

    postdata = [{'client': 'local', 'tgt': target, 'fun': 'grains.item', 'arg': ['id'], 'expr_form': 'ipcidr'}]

    resp = session.post(url, json=postdata)

    jsonobj = resp.json()['return']

    # check for null result (actually: a list with a single empty dict)
    if (len(jsonobj[0])) == 0:
        return None
    else:
        return str(jsonobj[0].values()[0]['id'])


def findsaltminion(url, username, password, ipaddr):
    """ find a salt minion using ip address """

    # make sure a valid IP address was specified
    if ipaddr is not None:
        try:
            valid_ip = socket.inet_aton(ipaddr)
        except socket.error:
            return
    else:
        return

    session = requests.Session()
    # session.verify = False

    # when logging in, hit /login instead of just url
    loginurl = "{}/{}".format(url, "login/")

    post = session.post(loginurl, json={
        'username': username,
        'password': password,
        'eauth': 'pam',
    })

    if post.status_code == 200:
        resp = session.post(url, json=[{
            'client': 'local',
            'tgt': ipaddr,
            'fun': 'grains.items',
            'expr_form': 'ipcidr'
        }])

        jsonobj = resp.json()['return']

        # check for null result (actually: a list with a single empty dict)
        if (len(jsonobj[0])) == 0:
            return None
        else:
            return jsonobj
    else:
        return None


def handle_db_record(uuid, record, dbrecords, dbconn):
    """
    Either insert a new record into the database for this record, or update it
    """

    # for now - this just spits out a dictionary
    # need to have it work with either MySQL or Redis...

    # let's see if we have this record in the database already...
    db_matched = None
    if dbrecords is not None:
        for dbrec in dbrecords:
            if dbrec['UUID'] == uuid:
                db_matched = dbrec

    sqlupdate = None
    if db_matched is None:
        sqlquery = "INSERT INTO lab_servers (VMName, minionid, vmwareToolsStatus, PowerState, UUID, MemoryMB," \
                   " ipAddr, GuestOS, HostName, lastUpdate, NumCPU)" \
                   " VALUES ('{VMName}', '{minionid}', '{vmwareToolsStatus}', '{PowerState}', '{UUID}', '{MemoryMB}'," \
                   " '{ipAddr}', '{GuestOS}', '{HostName}', '{lastUpdate}', '{NumCPU}')".format(**record)
        sqlupdate = 1
    else:
        sqlquery = "UPDATE lab_servers SET VMName = '{VMName}', minionid = '{minionid}'," \
                   " vmwareToolsStatus = '{vmwareToolsStatus}', PowerState = '{PowerState}', MemoryMB = '{MemoryMB}'," \
                   " NumCPU = '{NumCPU}', ipAddr = '{ipAddr}', GuestOS = '{GuestOS}', HostName = '{HostName}'," \
                   " lastUpdate = '{lastUpdate}' WHERE UUID = '{UUID}'".format(**record)
        for key in record.keys():
            if db_matched[key] != record[key]:
                print("{}: DB: {} ({}) -- Script: {} ({})".format(key, db_matched[key], type(db_matched[key]), record[key], type(record[key])))
                sqlupdate = 1


    # result = {record['VMName']: record}
    # return result
    if sqlupdate is None:
        return 0
    else:
        print(sqlquery)
        dbresult = db_updateinsert(dbconn, sqlquery)
        return dbresult


def db_connect(dbhost, dbuser, dbpasswd, dbname):
    """ open connection to database """
    dbconn = MySQLdb.Connection(host=dbhost, user=dbuser, passwd=dbpasswd, db=dbname)

    return dbconn


def db_updateinsert(dbconn, query):
    """ execute query against open db connection """
    cur = dbconn.cursor()
    cur.execute(query)
    dbconn.commit()

    return cur.rowcount


def db_select(dbconn, query):
    """ use a select statement to get records from the database """
    cur = dbconn.cursor(MySQLdb.cursors.DictCursor)
    cur.execute(query)
    records = cur.fetchall()

    return records


def get_db_records(dbhost, dbuser, dbpasswd, dbname):
    """ get all existing records from database """
    db = MySQLdb.Connection(host=dbhost, user=dbuser, passwd=dbpasswd, db=dbname)
    cur = db.cursor(MySQLdb.cursors.DictCursor)

    query = "SELECT * FROM lab_servers"

    cur.execute(query)
    records = cur.fetchall()

    return records


def get_vmware_inventory(host, user):
    """ retrieve ALL vm records from vCenter API """

    # this prevents subjectAltName warnings with the SSL certificates we get back...
    requests.packages.urllib3.disable_warnings()

    vcenterprompt = "Please enter your password for vCenter\n(username: {}, host: {}) ".format(user, host)
    vcenterpassword = getpassword(vcenterprompt)

    si = None
    try:
        si = SmartConnectNoSSL(host=host, user=user, pwd=vcenterpassword, port=int(443))
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

    return results


def get_salt_inventory(host, user):
    """ Retrieve grains.items from all Salt minions """

    # here's where we store the values
    results = []

    # establish session with Salt API
    saltprompt = "Please enter your password for Salt API\n(username: {}, host: {}) ".format(user, host)
    password = getpassword(saltprompt)

    session = requests.Session()
    # session.verify = False

    # when logging in, hit /login instead of just url
    loginurl = "https://{}/{}".format(host, "login/")
    posturl = "https://{}".format(host)

    post = session.post(loginurl, json={
        'username': user,
        'password': password,
        'eauth': 'pam'
    })

    # make sure the session was authenticated
    if post.status_code != 200:
        return "Invalid Login or Other Error"

    postdata = [{'client': 'local', 'tgt': '*', 'fun': 'grains.items'}]

    resp = session.post(posturl, json=postdata)

    jsonobj = resp.json()['return']

    # check for null result (actually: a list with a single empty dict)
    if (len(jsonobj[0])) == 0:
        return None
    else:
        # return jsonobj[0].values()
        cmdrun = None
        for minion in jsonobj[0].values():
            if minion['kernel'] == "Linux":
                cmdrun = ["yum --setopt=history_list_view=commands history | grep 'upgrade  \|update  ' | head -n1 | cut -d \| -f 3 | cut -d ' ' -f 2"]
            elif minion['kernel'] == "Windows":
                cmdrun = ['(get-hotfix | Sort-Object InstalledOn -Descending | Select-Object -First 1 | Measure-Object InstalledOn -Maximum | select Maximum).Maximum', 'shell=powershell']
            else:
                lastupdate = "N/A"

            if cmdrun is not None:
                # process the results from Salt
                postdata = [{'client': 'local', 'tgt': minion['id'], 'fun': 'cmd.run', 'arg': cmdrun}]
                resp = session.post(posturl, json=postdata)
                lastupdate = resp.json()['return'][0][minion['id']]

            # store the UUID in a consistent format (we'll do the same thing for VMware)
            uuid = re.sub('^VMware-', '', minion['serialnumber'])
            uuid = re.sub('-', '', uuid)
            uuid = re.sub(' ', '', uuid)

            # debug
            print("Debug: Minion: {} :: cmdrun: {} :: lastupdate: {}".format(minion['id'], cmdrun, lastupdate))

            salt_inventory = {
                "minionid": minion['id'],
                "uuid": str(uuid),
                "lastupdate": lastupdate
            }

            results.append(salt_inventory)

        return results


def process_inventory(vminventory, saltinventory):
    """
    Takes both inventory items, turns them into a single object, and then compares it to the database inventory

    :param vminventory:
    :param saltinventory:
    :return:
    """

    # get all records from MySQL database
    # dbresults = get_db_records('10.99.55.5', 'benjamin.brown', 'c00lp@ssw0rd', 'vm_inventory')
    dbconn = db_connect('10.99.55.5', 'benjamin.brown', 'c00lp@ssw0rd', 'vm_inventory')
    dbresults = db_select(dbconn, 'select * from lab_servers')

    # process results
    for item in vminventory:
        print("VM: {} :: UUID: {} :: IP Address: {}".format(item.config.name, item.config.uuid, item.guest.ipAddress))

        # find the minion ID of this object, if it exists
        minionid = None
        saltgrains = None
        vmware_uuid = re.sub('-', '', item.config.uuid)
        for saltitem in saltinventory:
            if vmware_uuid == saltitem['uuid']:
                minionid = saltitem['minionid']
                saltgrains = saltitem

        ## TODO:
        inventory_dict = {
            "Name": item.config.name,
            "UUID": vmware_uuid,
            "GuestOS": item.config.guestFullName,
            "PowerState": item.runtime.powerState,
            "NumCPU": str(item.config.numCpu).strip(),
            "MemoryMB": str(item.config.memorySizeMB).strip(),
            "ipAddr": str(item.guest.ipAddress),
            "lastUpdate": saltgrains['lastupdate']
        }


        # push the data to the database
        # record = handle_db_record(item.config.uuid, inventory_item, dbresults, dbconn)
        pprint.pprint(inventory_dict)

        print("====>\n")



def main():
    """
    Simple command-line program for listing the virtual machines on a host.
    """

    # command-line arguments
    args = setup_args()

    # connect to VMware and get all VMs
    vminventory = get_vmware_inventory(args.vcenterhost, args.vcenteruser)

    # get all grains from all minions in Salt
    saltinventory = get_salt_inventory(args.salthost, args.saltuser)

    results = process_inventory(vminventory, saltinventory)

    #### DEBUGGING
    # pp = pprint.PrettyPrinter(indent=4)
    # for item in saltinventory:
    #     pp.pprint(item['id'])
    exit(9)


# Start program
if __name__ == "__main__":
    main()
