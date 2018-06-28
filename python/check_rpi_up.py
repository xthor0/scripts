#!/usr/bin/env python

import time
import pprint
from datetime import datetime
import httplib
import urllib
from platform import system as system_name  # Returns the system/OS name
from subprocess import call as system_call  # Execute a shell command
import subprocess
import argparse

# we need some arguments provided to us
parser = argparse.ArgumentParser()
parser.add_argument('-c', '--pings', help='Number of pings to send', required=True, type=int)
parser.add_argument('-s', '--sleep', help='How long to sleep between ping sessions', required=True, type=int)
parser.add_argument('-H', '--host', help='FQDN or IP to ping', required=True)
parser.add_argument('-U', '--usertoken', help='Pushover User API Token')
parser.add_argument('-A', '--apptoken', help='Pushover App API Token')
args = parser.parse_args()


def old_ping(host):
    """
    Returns True if host (str) responds to a ping request.
    Remember that a host may not respond to a ping (ICMP) request even if the host name is valid.
    """

    # Ping command count option as function of OS
    param = '-n' if system_name().lower() == 'windows' else '-c'

    # Building the command. Ex: "ping -c 1 google.com"
    command = ['ping', param, '1', host]

    # Pinging
    return system_call(command) == 0


def ping(host):
    try:
        subprocess.check_output(
            ['ping', '-c', str(args.pings), '-q', host],
            stderr=subprocess.STDOUT,  # get all output
            universal_newlines=True  # return string not bytes
        )
        return True
    except subprocess.CalledProcessError:
        return False


class PingFailed(Exception): pass

# start measuring how long this script has been running!
start_time = datetime.now()

# loop till status changes
failcount = 0
maxfails = 3
while True:
    print('{} : Pinging {} ({} pings)...'.format(datetime.now(), args.host, args.pings))
    result = ping(args.host)
    if result is True:
        # reset failcount if necessary
        failcount = 0
        print("Success! Sleeping {} seconds...".format(args.sleep))
        time.sleep(args.sleep)
    else:
        failcount = failcount + 1
        print("Ping failure: {} of {}".format(failcount, maxfails))
        if failcount >= maxfails:
            print("Maximum ping failures reached!")
            break
        else:
            print("Sleeping 5 seconds before retry...")
            time.sleep(5)

# calculate time spent running
time_elapsed = datetime.now() - start_time

# print('Time elapsed (hh:mm:ss.ms) {}'.format(time_elapsed))
msg_time_elapsed = 'Host {} is down! Time elapsed (hh:mm:ss.ms) {}'.format(args.host, time_elapsed)

print(msg_time_elapsed)

print("Sending pushover message...")

# send a pushover message
if args.usertoken is not None:
    if args.apptoken is not None:
        conn = httplib.HTTPSConnection("api.pushover.net:443")
        conn.request("POST", "/1/messages.json",
          urllib.urlencode({
            "token": args.apptoken,
            "user": args.usertoken,
            "message": msg_time_elapsed,
          }), { "Content-type": "application/x-www-form-urlencoded" })
        conn.getresponse()
    else:
        print("Pushover API tokens not supplied - no message will be sent!")
else:
    print("Pushover API tokens not supplied - no message will be sent!")

# die
exit(0)
