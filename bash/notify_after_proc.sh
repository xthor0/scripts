#!/bin/bash

while [ -d /proc/5117 ]; do echo -n "."; sleep 10; done; ~/prowl.pl -apikey=fb18cb558102482e883ac76ba05a3c1b00212e96 -application=vhost_check -event="kaplan import completed" -notification="kaplan import completed at `date`" -priority=0
