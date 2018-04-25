#!/bin/bash

/opt/splunkforwarder/bin/splunk add forward-server splunk.datamark.com:9999 -auth admin:changeme
/opt/splunkforwarder/bin/splunk remove forward-server copenhagen101.datamark-inc.com:9999 -auth admin:changeme
/opt/splunkforwarder/bin/splunk enable boot-start
/sbin/chkconfig --add splunk

exit 0