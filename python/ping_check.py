#!/usr/bin/env python

import time
import subprocess
import argparse
import logging
from os.path import expanduser
import signal

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

class GracefulKiller:
  kill_now = False
  def __init__(self):
    signal.signal(signal.SIGINT, self.exit_gracefully)
    signal.signal(signal.SIGTERM, self.exit_gracefully)

  def exit_gracefully(self,signum, frame):
    self.kill_now = True


# we log to $HOME
home = expanduser("~")
logfile = "{}/{}.log".format(home,args.host)

if args.verbose is False:
  print('Ping check of host {} started. Logging to file {}.'.format(args.host, logfile))

# logging
logger = logging.getLogger('ping_check')
hdlr = logging.FileHandler(logfile)
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.INFO)

# log app starting
logger.info('App started')

# ping away
if __name__ == '__main__':
  status = None
  lastStatus = None
  killer = GracefulKiller()
  while not killer.kill_now:
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

  # log a message and exit
  logger.info('App stopped')
