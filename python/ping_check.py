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
import logging
from os.path import expanduser

# we need some arguments provided to us
parser = argparse.ArgumentParser()
parser.add_argument('-c', '--pings', help='Number of pings to send', required=True, type=int)
parser.add_argument('-s', '--sleep', help='How long to sleep between ping sessions', required=True, type=int)
parser.add_argument('-H', '--host', help='FQDN or IP to ping', required=True)
parser.add_argument('-v', '--verbose', help='Be more chatty', action='store_true')
args = parser.parse_args()


def ping(host):
    try:
        subprocess.check_output(
            ['ping', '-c', str(args.pings), '-w', str(args.pings), '-q', host],
            stderr=subprocess.STDOUT,  # get all output
            universal_newlines=True  # return string not bytes
        )
        return True
    except subprocess.CalledProcessError:
        return False


class PingFailed(Exception): pass

# we log to $HOME
home = expanduser("~")
logfile = "{}/pingcheck.log".format(home)

if args.verbose is False:
  print('Ping check of host {} started. Logging to file {}.'.format(args.host, logfile))

# logging
logger = logging.getLogger('ping_check')
hdlr = logging.FileHandler(logfile)
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.INFO)

# write a log message
logger.info('App started')

# loop forever
status = None
lastStatus = None
while True:
  # print out a message if we're running for the first time
  if lastStatus is None:
    message = 'Pinging {} ({} pings)...'.format(args.host, args.pings)
    if args.verbose is True:
      print(message)
    logger.info(message)
  
  # ping the host and record result
  result = ping(args.host)

  if result is True:
    status = "UP"
  else:
    status = "DOWN"

  # now check if the status has changed
  if lastStatus is None:
    message = "Host {} is {}!".format(args.host, status)
    if args.verbose is True:
      print(message)
    logger.info(message)
    lastStatus = status
  else:
    if status == lastStatus:
      # there has been no change, so all we do is log it
      message = "Host {} : No change (still {})".format(args.host, status)
      logger.info(message)
    else:
      message = "Host {} status has changed from {} to {}!".format(args.host, lastStatus, status)
      if args.verbose is True:
        print(message)
      logger.warning(message)

  # set lastStatus to status
  lastStatus = status

  # sleep
  time.sleep(args.sleep)


# commented, may use later
"""
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
"""

# die
exit(0)
