#!/usr/bin/env python

import httplib
import urllib
from datetime import datetime
from subprocess import check_output
import socket
import argparse

# get command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-U', '--usertoken', help='Pushover User API Token')
parser.add_argument('-A', '--apptoken', help='Pushover App API Token')
args = parser.parse_args()

# IP address
ips = check_output(['hostname', '--all-ip-addresses'])

# construct message
message = "{} booted up at {} with IP {}".format(socket.gethostname(), datetime.now(), ips)

print(message)

# send a pushover message
if args.usertoken is not None:
    if args.apptoken is not None:
        conn = httplib.HTTPSConnection("api.pushover.net:443")
        conn.request("POST", "/1/messages.json",
          urllib.urlencode({
            "token": args.apptoken,
            "user": args.usertoken,
            "message": message,
          }), { "Content-type": "application/x-www-form-urlencoded" })
        conn.getresponse()
    else:
        print("Pushover API tokens not supplied - no message will be sent!")
else:
    print("Pushover API tokens not supplied - no message will be sent!")
