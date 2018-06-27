#!/usr/bin/env python

import time
import pprint
from datetime import datetime
import httplib
import urllib
from platform import system as system_name  # Returns the system/OS name
from subprocess import call as system_call  # Execute a shell command


def ping(host):
    """
    Returns True if host (str) responds to a ping request.
    Remember that a host may not respond to a ping (ICMP) request even if the host name is valid.
    """

    # Ping command count option as function of OS
    param = '-n' if system_name().lower()=='windows' else '-c'

    # Building the command. Ex: "ping -c 1 google.com"
    command = ['ping', param, '1', host]

    # Pinging
    return system_call(command) == 0


# start measuring how long this script has been running!
start_time = datetime.now()

# loop till status changes
while True:
    print('Pinging 10.200.105.106/24...')
    result = ping('10.200.105.106')
    if result is not True:
        print('Ping failed!')
        break
    print("Sleeping 5...")
    time.sleep(5)

# calculate time spent running
time_elapsed = datetime.now() - start_time

# print('Time elapsed (hh:mm:ss.ms) {}'.format(time_elapsed))
msg_time_elapsed = 'The Raspberry Pi Zero finally died! Time elapsed (hh:mm:ss.ms) {}'.format(time_elapsed)

print(msg_time_elapsed)

# send a pushover message
conn = httplib.HTTPSConnection("api.pushover.net:443")
conn.request("POST", "/1/messages.json",
  urllib.urlencode({
    "token": "acu2n6t3qchjinsjgd9qtx1m5vfha4",
    "user": "uiLUuynXsvF7UCQATr3j6j7pG7dGoh",
    "message": msg_time_elapsed,
  }), { "Content-type": "application/x-www-form-urlencoded" })
conn.getresponse()

# die
exit(0)