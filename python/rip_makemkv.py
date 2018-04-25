#!/usr/bin/env python

import subprocess
import shlex
import re
import os
import time
from unidecode import unidecode
from progress.bar import Bar
from decimal import *

class Disc():
    def __init__(self, device):
        self.device = device

    def get_info(self):
        cmdLine = "/usr/bin/makemkvcon --progress=-stdout -r info dev:{}".format(self.device)
        cmd = shlex.split(cmdLine)
        print "Scanning disc on device {} for title, please wait...".format(self.device)
        self.discinfo = subprocess.check_output(cmd)

    def count_titles(self):
        pattern = re.compile('^TCOUNT')
        for line in self.discinfo.splitlines():
            if pattern.match(line.strip()):
                parse = line.split(":")
                self.titlecount = int(parse[1])

    def get_title(self):
        pattern = re.compile('^TINFO:0,2,0.*')
        for line in self.discinfo.splitlines():
            if pattern.match(line.strip()):
                parse = line.split(",")
                parse = parse[3].replace('"', '')
                #parse = parse.replace(' ', '_')
                #parse = unidecode(unicode(parse, encoding = "utf-8"))
        try:
            self.title = parse
        except NameError:
            self.title = "Unknown"

    def get_largest_title(self):
        pattern = re.compile('^TINFO:[0-9][0-9]?,11,0')
        self.titles = []
        titleSizes = []
        for line in self.discinfo.splitlines():
            if pattern.match(line.strip()):
                parse = line.split(",")
                size = int(parse[3].replace('"', ''))
                parsetitlenum = parse[0].split(":")
                titlenum = int(parsetitlenum[1])
                obj = [titlenum, size]
                titleSizes.append(size)
                self.titles.append(obj)
                # debugging
                #print "Line: {} :: Title: {} :: Size: {}".format(line, titlenum, size)

        max_sub = max(self.titles, key=lambda x: x[1])
        self.titletorip = max_sub[0]
        #max_index = max_sub[0]
        #print max_sub

        #self.titletorip = max(titleSizes)
        #print titleSizes

        #counter = collections.Counter(titleSizes)
        #print counter.most_common(self.titletorip)

    def get_title_filename(self):
        pattern = re.compile('^TINFO:{},27,0'.format(self.titletorip))
        for line in self.discinfo.splitlines():
            if pattern.match(line.strip()):
                parse = line.split(',')
                self.filename = parse[3].replace('"', '')

    def ripOldWay(self):
        ''' should be removed - only here for reference, see rip def '''
        self.path = "/storage/new_rips/{}".format(self.title)
        if os.path.exists(self.path):
            print "Directory {} already exists -- exiting!!".format(self.path)
            exit()
        else:
            os.makedirs(self.path)
        cmdLine = "/usr/bin/makemkvcon -r --messages=-stdout --progress=-stdout mkv dev:{} {} {}".format(self.device, self.titletorip, self.path)
        cmd = shlex.split(cmdLine)
        print "Ripping movie {} (title # {}), please wait...".format(self.title, self.titletorip)
        #makemkv = subprocess.check_output(cmd)
        #os.spawnl(os.P_NOWAIT, cmd)
        pattern = re.compile('^PRGV:')
        start = re.compile('^PRGC:.*"Saving to MKV file"')
        percent = 1
        nextPct = 1
        scanning = 1
        message = 'Ripping {} :: '.format(self.title)
        bar = Bar(message, fill='#', suffix='%(percent)d%%')
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        while process.poll() is None:
            for line in iter(process.stdout.readline, ''):
                # first, we're looking for a message like 'PRGC:5017,0,"Saving to MKV file"'
                # we don't start the actual PROGRESS bar till we see this...
                if scanning == 1:
                    if start.match(line.strip()):
                        scanning = 0
                else:
                    if pattern.match(line.strip()):
                        linearr = line.split(',')
                        current = Decimal(linearr[1])
                        complete = Decimal(linearr[2])
                        percent = (current / complete) * 100
                        if percent >= nextPct:
                            bar.next()
                            nextPct = nextPct + 1
                        #print('Percent completed: {}%').format(percent)

            # half-second sleep before the next run!
            time.sleep(0.5)

        # if we get here - we're done!
        bar.finish()

        # we're done
        print "Rip complete!"

    def rip(self, path):
        self.path = path
        self.fullpath = "{}/{}".format(self.path, self.filename)
        if os.path.isfile(self.fullpath):
            print "File {} already exists -- exiting!!".format(self.fullpath)
            exit()

        cmdLine = "/usr/bin/makemkvcon -r --messages=-stdout --progress=-stdout mkv dev:{} {} {}".format(self.device, self.titletorip, self.path)
        cmd = shlex.split(cmdLine)
        print "Scanning disc {} (title # {}), please wait...".format(self.title, self.titletorip)
        pattern = re.compile('^PRGV:')
        start = re.compile('^PRGC:.*"Saving to MKV file"')
        percent = 1
        nextPct = 1
        scanning = 1
        message = 'Ripping {} to file {} ::'.format(self.title, self.fullpath)
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE)
        while process.poll() is None:
            for line in iter(process.stdout.readline, ''):
                # first, we're looking for a message like 'PRGC:5017,0,"Saving to MKV file"'
                # we don't start the actual PROGRESS bar till we see this...
                if scanning == 1:
                    if start.match(line.strip()):
                        bar = Bar(message, fill='#', suffix='%(percent)d%%')
                        scanning = 0
                else:
                    if pattern.match(line.strip()):
                        linearr = line.split(',')
                        current = Decimal(linearr[1])
                        complete = Decimal(linearr[2])
                        percent = (current / complete) * 100
                        if percent >= nextPct:
                            bar.next()
                            nextPct = nextPct + 1

            # half-second sleep before the next run!
            time.sleep(0.5)

        # if we get here - we're done!
        bar.finish()

        # we're done
        print "Rip complete!"

### main
newDisc = Disc("/dev/sr0")
newDisc.get_info()

newDisc.count_titles()
if newDisc.titlecount >= 30:
    print('ERROR: This disc has a LOT of titles ({})! This probably means some copy protection scheme is in use.'.format(newDisc.titlecount))
    print('Please look at the makemkvcon output manually and decide how best to proceed.')
    exit()

newDisc.get_title()
#print('Disc title: {}').format(newDisc.title)

newDisc.get_largest_title()
newDisc.get_title_filename()

newDisc.rip("/storage/new_rips/Pending")

## TODO: encode whatever we ripped with HandBrake...

'''
if newDisc.samesizetitles == 0:
    newDisc.rip()
else:
    print "Can't rip {} - multiple titles found that are the same size!".format(newDisc.title)
    print newDisc.titles
'''
