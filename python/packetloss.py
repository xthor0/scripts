#!/usr/bin/env python3

import json
import pingparsing
import pprint
import argparse
import netifaces
import time
import signal
import subprocess
import re
from sys import platform
from datetime import datetime


# trap CTRL-C for graceful exit
def signal_handler(sig, frame):
    print('\nCTRL-C pressed, exiting...')
    # eventually, close the log output...
    exit(0)

# a function to return the SSID and BSSID
def get_wifi_info():
    if platform == 'linux' or platform == 'linux2':
        ssid = subprocess.getoutput('iwgetid -r')
        # this is an assumption - I should probably cobble something together to make this less presumptive
        bssid_output = subprocess.getoutput('iwconfig wlan0')
        lineArr = bssid_output.split('\n')
        for line in lineArr:
            search = re.search("Access Point:", line)
            if(search):
                found = line.split()
                bssid = found[5]
        try:
            bssid
        except NameError:
            bssid = 'Unknown'
    elif platform == 'darwin':
        ssid = subprocess.getoutput('/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep \' SSID\' | awk \'{ print $2 }\'')
        bssid = subprocess.getoutput('/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep \' BSSID\' | awk \'{ print $2 }\'')
    elif platform == 'win32':
        #output = subprocess.check_output("netsh wlan show interfaces")
        # I may never write this, but just in case, there's the command to start with
        bssid = 'needs work!'
        ssid = 'needs work!'
    else:
        ssid = 'Unknown'
        bssid = 'Unknown'
    
    return({'bssid': bssid, 'ssid': ssid})

# tell SIGNINT it needs to go through signal_handler
signal.signal(signal.SIGINT, signal_handler)

# get default gateway
gws = netifaces.gateways()
defgw = gws['default'][netifaces.AF_INET][0]

# get command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-H', '--host', help='Host or IP address to ping', default=defgw, type=str)
parser.add_argument('-c', '--count', help='Packets to sned', default=10, type=int)
parser.add_argument('-s', '--sleep', help='time in seconds to wait between loops', default=1, type=int)
parser.add_argument('-d', '--daemon', help='Run in background (logging to file)', action='store_true')
args = parser.parse_args()

# tell the user... something
print("Ping loop starting. Pinging {} (sending {} packets)...".format(args.host, args.count))

# let's get pinging
while True:
    wlaninfo = get_wifi_info()
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
            "{:20} || {:7} || {:30} || {:17} || {:>5} || {:>5} || {:>7} || {:>7} || {:>5}".format('Datestamp', 'Counter', 'SSID', 'BSSID', 'Sent', 'Recd', 'RTT Avg', 'RTT Max', 'Loss'))
        print("-=-=" * 37)

    print("{:20} || {:7.0f} || {:30} || {:17} || {:5.0f} || {:5.0f} || {:7.2f} || {:7.2f} || {:5.2f}%".format(str(datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
                                                                        counter, wlaninfo['ssid'], wlaninfo['bssid'], output['packet_transmit'],
                                                                output['packet_receive'], output['rtt_avg'], output['rtt_max'], output['packet_loss_rate']))

    # increment counter and sleep
    counter = counter+1
    time.sleep(args.sleep)