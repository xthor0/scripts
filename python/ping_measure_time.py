#!/usr/bin/env python

import time
import pprint
from datetime import datetime
from platform import system as system_name  # Returns the system/OS name
from subprocess import call as system_call  # Execute a shell command
import subprocess
import argparse

# we need some arguments provided to us
parser = argparse.ArgumentParser()
parser.add_argument('-H', '--host', help='FQDN or IP to ping', required=True)
args = parser.parse_args()


def ping(host):
    try:
        subprocess.check_output(
            ['ping', '-c1', '-w1', '-q', host],
            stderr=subprocess.STDOUT,  # get all output
            universal_newlines=True  # return string not bytes
        )
        return True
    except subprocess.CalledProcessError:
        return False


class PingFailed(Exception): pass

# start measuring how long this script has been running!
start_time = datetime.now()

# loop till there are ping responses
while True:
    print('{} : Pinging host {}...'.format(datetime.now(), args.host))
    result = ping(args.host)
    if result is True:
        print("Host is up!")
        break
    else:
        time.sleep(1)

# calculate time spent running
time_elapsed = datetime.now() - start_time

# print('Time elapsed (hh:mm:ss.ms) {}'.format(time_elapsed))
msg_time_elapsed = 'Host {} is up! Time elapsed (hh:mm:ss.ms) {}'.format(args.host, time_elapsed)

print(msg_time_elapsed)

# die
exit(0)
