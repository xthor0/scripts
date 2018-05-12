import requests
import pprint
import configparser
import json
import os

# TODO: I could build this better - split out the requests part to maybe a post, get, delete, patch functions?


class PHPIpamClient(object):
    """API client for accessing PHPIpam"""

    def load_ini(self, inifile):
        """ Parse info from INI file that holds configuration values for connecting to IPAM API """
        settings = configparser.ConfigParser()
        settings.read(inifile)
        self.apiusername = settings.get('PHPIPAM', 'api.username')
        self.apipassword = settings.get('PHPIPAM', 'api.password')
        self.apihostname = settings.get('PHPIPAM', 'api.hostname')
        self.apiappname = settings.get('PHPIPAM', 'api.appname')

    def authenticate(self, apihostname, apiappname, apiusername, apipassword):
        """ connect to PHPIPAM API and get authentication token """

        # Set the request parameters
        url = 'https://{}/phpipam/api/{}/user/'.format(apihostname, apiappname)

        # Set proper headers
        headers = {"Content-Type": "application/json", "Accept": "application/json"}

        # Do the HTTP request
        response = requests.post(url, auth=(apiusername, apipassword), headers=headers)

        # Check for HTTP codes other than 200
        if response.status_code != 200:
            print('Status:', response.status_code, 'Headers:', response.headers, 'Error Response:', response.json())
            exit()

        # Decode the JSON response into a dictionary and use the data
        # all results are returned inside the 'result' object, so we strip that out
        try:
            data = response.json()['data']
        except IndexError:
            self.apitoken = None
            return

        # make sure the response back had a token -- this tells us we're authenticated
        try:
            self.apitoken = data['token']
        except IndexError:
            self.apitoken = "Error"

    def api_get_next_free_ip(self, subnet, apihostname, apitoken, apiappname):
        """ Grab the next available IP from specified subnet """
        url = 'https://{}/phpipam/api/{}/subnets/cidr/{}/'.format(apihostname, apiappname, subnet)

        # the header will need to contain the token we got back when we authenticated earlier
        headers = {"Content-Type": "application/json", "Accept": "application/json", "token": apitoken}

        # Do the HTTP request
        r = requests.get(url, headers=headers)

        # Check for HTTP codes other than 200
        if r.status_code != 200:
            print("Error - HTTP response code {} (expected: 200)".format(r.status_code))
            print("Response: {}".format(r.json()['message']))
            return

        # if success is set to 0 then it means the search failed
        if r.json()['success'] == 0:
            print("Subnet not found.")
            return

        # we need some data from the search request
        try:
            subnetid = r.json()['data'][0]['id']
        except IndexError:
            self.ipaddr = "Error"
            print("Can't get subnet ID")
            return

        # get the next available IP address in the subnet we just searched for
        url = 'https://{}/phpipam/api/{}/subnets/{}/first_free/'.format(apihostname, apiappname, subnetid)
        r = requests.get(url, headers=headers)

        # Check for HTTP codes other than 200
        if r.status_code != 200:
            print("Error - HTTP response code {} (expected: 200)".format(r.status_code))
            print("Response: {}".format(r.json()['message']))
            exit()

        try:
            self.ipaddr = r.json()['data']
        except IndexError:
            self.ipaddr = "Error"
            print("Can't get a free IP address")
            return

    def get_ip_old(self, subnet):
        """ An easier wrapper to get a free IP """
        self.api_get_next_free_ip(subnet, self.apihostname, self.apitoken, self.apiappname)

    def api_register_ip_to_host(self, ipaddr):
        """ register IP address to a host """

    def api_post(self, method, url, headers):
        """ make a request to API using HTTP POST, and return request results """

    def build_url(self, apihostname, apiappname, args):
        """ a function to build the appropriate URL to feed to apicall """
        if args is not None:
            self.apiurl = "https://{}/phpipam/api/{}/{}/".format(apihostname, apiappname, args)
        else:
            self.apiurl = "https://{}/phpipam/api/{}/".format(apihostname, apiappname)

    def api_call(self, url, method, payload, apitoken):
        """
        I'm trying to write a generic function that can be used to do multiple things
        several of PHPIpam's API calls are different - a POST to create new, or get info
        a PATCH to update information
        a DELETE to remove something
        I'd like to do this ONCE and parse the output accordingly...
        """

        # build headers - json requests only!
        headers = {"Content-Type": "application/json", "Accept": "application/json", "token": apitoken}

        # if we are doing a POST, PATCH, or DELETE we expect payload
        if payload is not None:
            if method == "get":
                print("Error: HTTP get does not expect payload")
                return
            else:
                # check to make sure the payload specified is a JSON object (need to code for this)
                # TODO: this isn't working - this should cause the call to return if the supplied data isn't JSON
                try:
                    jsontest = json.loads(payload)
                except ValueError, e:
                    return False

        # we also need PATCH and DELETE (patch changes data, delete... well, deletes)
        if method == "get":
            r = requests.get(url, headers=headers)
            exp_status_code = 200
        elif method == "post":
            r = requests.post(url, data=payload, headers=headers)
            exp_status_code = 201
        elif method == "delete":
            r = requests.delete(url, data=payload, headers=headers)
            exp_status_code = 200
        else:
            print("Invalid HTTP request method: {}".format(method))
            return

        # if we didn't get a 200, or a 201, the request wasn't successful
        if r.status_code != exp_status_code:
            print("Error - HTTP response code {} (expected: {})".format(r.status_code, exp_status_code))
            print("Response: {}".format(r.json()['message']))
            return

        # parse the data if we got it - but only if method is get
        if method == "get":
            try:
                self.apiresponse = r.json()['data']
            except KeyError:
                print("Error: Invalid JSON response")
                self.action_status = False
                return
        else:
            try:
                self.apiresponse = r.json()['message']
            except KeyError:
                print("Request Failed")
                return

    def get_ip(self, subnet):
        """ Get next available IP address in subnet """
        # first, make an API call to get the subnet ID
        args = "{}/{}".format("subnets/cidr", subnet)
        self.build_url(self.apihostname, self.apiappname, args)
        self.api_call(self.apiurl, "get", None, self.apitoken)

        # next, make an API call to get the next free IP address in that subnet
        try:
            if self.apiresponse[0]['id']:
                self.subnetid = self.apiresponse[0]['id']
                args = "subnets/{}/first_free".format(self.subnetid)
                self.build_url(self.apihostname, self.apiappname, args)
                self.api_call(self.apiurl, "get", None, self.apitoken)

                # finally, pull the IP address out of the mix
                self.ipaddr = self.apiresponse
            else:
                return
        except IndexError:
            return

    def register_ip(self, servername):
        """ Register IP address to a server in IPAM """
        # we need to build an object to store the payload to send to PHPIPAM to register this record
        postdata = {"description": "{} : Added from API by SaltStack".format(servername),
                    "hostname": servername, "ip": self.ipaddr, "subnetId": int(self.subnetid)}

        json_postdata = json.dumps(postdata)

        # build the URL to create the new address
        args = "addresses"
        self.build_url(self.apihostname, self.apiappname, args)
        self.api_call(self.apiurl, "post", json_postdata, self.apitoken)

    def delete_ip(self, ipaddr):
        """ Remove IP address record from IPAM """
        # workflow: make a request to IPAM to search for the IP address (get)
        # make another request that deletes the record from IPAM

        # build the URL to get the IP address ID
        args = "addresses/search/{}/".format(ipaddr)
        self.build_url(self.apihostname, self.apiappname, args)
        self.api_call(self.apiurl, "get", None, self.apitoken)

        try:
            self.id = self.apiresponse[0]['id']
        except TypeError:
            self.action_status = False
            print("Unable to find IP address {} in IPAM".format(ipaddr))
            return

        # now build the URL to get the IP deleted from IPAM
        args = "addresses/{}/".format(self.id)
        self.build_url(self.apihostname, self.apiappname, args)
        self.api_call(self.apiurl, "delete", None, self.apitoken)

        if self.apiresponse == "Address deleted":
            print("Address {} deleted from IPAM".format(ipaddr))
        else:
            print("Unable to delete IP address {} in IPAM".format(ipaddr))
        return

    def __init__(self):
        """ Return an IP address and the corresponding ID from IPAM"""
        self.id = None
        self.ipaddr = None
        self.apiusername = None
        self.apipassword = None
        self.apiappname = None
        self.apihostname = None
        self.apitoken = None
        self.apiurl = None
        self.apiresponse = None
        self.apiresponsecode = None
        self.subnetid = None
        self.action_status = False

        # load the ini file
        cwd = os.path.dirname(os.path.realpath(__file__))
        inifile = "{}/settings.ini".format(cwd)
        self.load_ini(inifile)

        if self.apitoken is None:
            self.authenticate(self.apihostname, self.apiappname, self.apiusername, self.apipassword)

        if self.apitoken == "Error":
            print("Error authenticating to API")
            return


