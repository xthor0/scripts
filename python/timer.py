#!/usr/bin/env python

import time

def timer(start,end):
    hours, rem = divmod(end-start, 3600)
    minutes, seconds = divmod(rem, 60)
    print("Elapsed time (H:M:S) :: {:0>2}:{:0>2}:{:05.2f}".format(int(hours),int(minutes),seconds))

print("This is the script that never ends... (CTRL-C to exit)")
start = time.time()
while True:
    time.sleep(10)
    end = time.time()
    timer(start, end)

