#!/usr/bin/env python

import requests
import configparser
import pprint
import json
import os


class SNOWAPIClient(object):
    """ define how we interact with SNOW API """

    def load_ini(self, inifile):
        """ variables for communicating with SNOW API are stored in an ini file, this loads those values"""
        settings = configparser.ConfigParser()
        settings.read(inifile)
        self.apihostname = settings.get('SNOW', 'api.hostname')
        self.apiusername = settings.get('SNOW', 'api.username')
        self.apipassword = settings.get('SNOW', 'api.password')

    def api_call(self, method, url, data):
        """ make a call to the SNOW API URL and return JSON object with results """
        # if we ever need to make more calls this could be made more generic, but... for now, all we do is
        # query for a ci_server_template so we'll make it less generic

        # Set proper headers
        headers = {"Content-Type": "application/json", "Accept": "application/json"}

        # Do the HTTP request
        if method == "get":
            exp_status_code = 200
            r = requests.get(url, auth=(self.apiusername, self.apipassword), headers=headers)
        elif method == "post":
            exp_status_code = 201
            r = requests.post(url, auth=(self.apiusername, self.apipassword), headers=headers, data=data)
        elif method == "patch":
            exp_status_code = 200
            r = requests.patch(url, auth=(self.apiusername, self.apipassword), headers=headers, data=data)
        elif method == "delete":
            exp_status_code = 204
            r = requests.delete(url, auth=(self.apiusername, self.apipassword), headers=headers)
        else:
            print("Invalid method: {}".format(method))
            return

        # Check for HTTP codes other than 200
        self.apistatuscode = r.status_code
        if r.status_code != exp_status_code:
            print("Error - HTTP response code {} (expected: {})".format(r.status_code, exp_status_code))
            return

        # Decode the JSON response into a dictionary and use the data
        # all results are returned inside the 'result' object, so we strip that out
        # unless we send a delete - then we return nothing
        if method == "delete":
            return
        try:
            self.apidata = r.json()['result']
        except KeyError:
            # TODO: change the print statement below - we're not always looking for a template with this call
            print("Unable to return json result, raw dump should follow.")
            pprint.pprint(r.json())
            return

    def load_template(self, template):
        url = 'https://{}/api/now/table/u_cmdb_ci_server_template?sysparm_query=u_name_prefix%3D{}'.format(
            self.apihostname, template)
        self.api_call("get", url, None)

        # make sure we only have ONE template, otherwise...
        if len(self.apidata) > 1:
            print("Error - more than one template named {} found in CMDB! Exiting...".format(template))
            return
        else:
            self.apidata = self.apidata[0]

        try:
            self.name_prefix = self.apidata['u_name_prefix']
        except IndexError:
            return

        self.vm_profile = self.apidata['u_vm_profile']
        self.salt_states = self.apidata['u_salt_states']
        self.core_count = self.apidata['cpu_core_count']
        self.ram = self.apidata['ram']

        # right now - the VLAN field holds data in this format
        # VMware network name:Subnet in CIDR format
        # here we break it out
        # might want to simply ask Tony to break these out for us - that would make more sense...
        self.vmnet = self.apidata['u_vlan'].split(':')[0]
        self.subnet = self.apidata['u_vlan'].split(':')[1]

    def create_ci(self, servername, ipaddr):
        """ create server CI in SNOW """
        url = 'https://{}/api/now/table/cmdb_ci_server'.format(self.apihostname)
        # TODO: this needs work. Environment and patching category SHOULD come from the template!
        # we can't set the patching category on the template - what happens when we leave it off?
        # dict_data = {'ip_address': ipaddr, 'name': servername, 'u_environment': 'lab', 'u_patching_category': 'Linux'}
        dict_data = {'ip_address': ipaddr, 'name': servername, 'u_environment': 'lab'}
        data = json.dumps(dict_data)
        self.api_call("post", url, data)
        if self.apistatuscode == 201:
            self.sys_id = self.apidata['sys_id']

        # TODO: lots of notes below
        # this is a mess. a few observations:
        # 1. you can create as many CIs as you like with the same name. I did it in QA and proved it.
        # 2. the IP address specified in the payload above doesn't seem to be registered anywhere in the CI
        # 3. if I can create as many server CIs with the same name as I like, then I need to run some logic.
        # -- do I check to see if there is an existing server CI with this name? If there is, does the script stop?
        # -- do we need to grab the serial number from the Salt cloud output so we can update the newly created CI?
        # --- if we don't do this, how does the API know that the server CI I just created belongs to a VM that
        # discovery finds when it runs?
        # steven will have to help with ALL of this tomorrow

    def get_ci_by_name(self, servername):
        """ get a server CI from SNOW using a server name """
        url = 'https://{}/api/now/table/cmdb_ci_server?name={}'.format(self.apihostname, servername)
        self.api_call("get", url, None)
        if len(self.apidata) > 1:
            print("ERROR: More than one CI named {} found!".format(servername))
            return
        if len(self.apidata) == 0:
            print("ERROR: No CI found with name {}!".format(servername))
            return
        self.sys_id = self.apidata[0]['sys_id']
        self.serialnum = self.apidata[0]['serial_number']
        self.name = self.apidata[0]['name']

    def get_ci_by_sysid(self):
        """ get a server CI from SNOW using a sys_id """
        if self.sys_id is None:
            return
        url = 'https://{}/api/now/table/cmdb_ci_server?sys_id={}'.format(self.apihostname, self.sys_id)
        self.api_call("get", url, None)

    def update_ci_sn(self, serialnumber):
        """ update a CI, using a given sys_id, to include VMware serial number """
        url = 'https://{}/api/now/table/cmdb_ci_server/{}'.format(self.apihostname, self.sys_id)
        dict_data = {"serial_number": serialnumber}
        data = json.dumps(dict_data)
        self.api_call("patch", url, data)

    def delete_ci(self):
        """ Delete CI from SNOW by sys_id """
        url = 'https://{}/api/now/table/cmdb_ci_server/{}'.format(self.apihostname, self.sys_id)
        self.api_call("delete", url, None)

    def __init__(self):
        self.apihostname = None
        self.apiusername = None
        self.apipassword = None
        self.apidata = None
        self.apistatuscode = None
        self.sys_id = None
        self.name_prefix = None
        self.vm_profile = None
        self.salt_states = None
        self.core_count = None
        self.ram = None
        self.vmnet = None
        self.subnet = None
        self.serialnum = None
        self.name = None

        cwd = os.path.dirname(os.path.realpath(__file__))
        inifile = "{}/settings.ini".format(cwd)
        self.load_ini(inifile)


