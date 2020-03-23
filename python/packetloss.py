#!/usr/bin/env python3

import json
import pingparsing
import pprint
import argparse
import netifaces
import time
import signal
from datetime import datetime


# trap CTRL-C for graceful exit
def signal_handler(sig, frame):
    print('\nCTRL-C pressed, exiting...')
    # eventually, close the log output...
    exit(0)


# tell SIGNINT it needs to go through signal_handler
signal.signal(signal.SIGINT, signal_handler)

# get default gateway
gws = netifaces.gateways()
defgw = gws['default'][netifaces.AF_INET][0]

# get command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-H', '--host', help='Host or IP address to ping', default=defgw, type=str)
parser.add_argument('-c', '--count', help='Packets to sned', default=10, type=int)
parser.add_argument('-d', '--daemon', help='Run in background (logging to file)', action='store_true')
args = parser.parse_args()

# tell the user... something
print("Ping loop starting. Pinging {} (sending {} packets)...".format(args.host, args.count))

# let's get pinging
while True:
    ping_parser = pingparsing.PingParsing()
    transmitter = pingparsing.PingTransmitter()
    transmitter.destination = args.host
    transmitter.count = args.count
    result = transmitter.ping()

    output = ping_parser.parse(result).as_dict()

    try:
        counter
    except NameError:
        counter = 1
        print(
            "{:20} || {:7} || {:15} || {:15} || {:8} || {:8} || {:15}".format('Datestamp', 'Counter', 'Packets Sent', 'Packets Received', 'RTT Avg', 'RTT Max', 'Packet Loss Pct'))
        print("-=-=" * 29)

    print("{:20} || {:7.0f} || {:15.0f} || {:16.0f} || {:8.2f} || {:8.2f} || {:15.1f}%".format(str(datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
                                                                        counter, output['packet_transmit'],
                                                                output['packet_receive'], output['rtt_avg'], output['rtt_max'], output['packet_loss_rate']))

    # increment counter and sleep
    counter = counter+1
    time.sleep(.5)