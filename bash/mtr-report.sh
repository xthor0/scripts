#!/bin/bash

while true; do echo -n "Start: "; date; mtr --report -i 5 -c 20 206.173.159.75; echo -n "End: "; date; echo =========; sleep 10; done >> /var/tmp/mtr-206.173.159.75.log
