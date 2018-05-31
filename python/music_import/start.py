#!/usr/bin/env python

import argparse
import os
import pprint
from tinytag import TinyTag
from os import listdir
from os.path import isfile, join

# get arguments from command-line
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--directory', required=True, help='Directory containing your music')
args = parser.parse_args()

# make sure what was passed *IS* actually a directory
if os.path.isdir(args.directory) is not True:
    print("Sorry, directory does not exist: {}".format(args.directory))
    exit(3)

# find all files in the directory specified
files = [os.path.join(args.directory, filename)
         for path, dirs, files in os.walk(args.directory)
         for filename in files]
pprint.pprint(files)

for file in files:
    tag = TinyTag.get(file)
    print('This track is by %s.' % tag.artist)
    print('It is %f seconds long.' % tag.duration)
    print('Next file ::>')

