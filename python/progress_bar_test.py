#!/usr/bin/env python

from progress.bar import Bar
import time

percent = 1
message = 'Ripping {} :: '.format('Some Movie')
bar = Bar(message, fill='#', suffix='%(percent)d%%')
while True:
    time.sleep(2)
    percent = percent + 2
    bar.next()
    if percent == 100:
        continue
bar.finish()
