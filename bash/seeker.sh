#!/bin/bash

if [ ! -x /usr/sbin/seeker ]; then
	echo "Missing seeker -- please install it."
	exit 255
fi

for i in `seq 1 6`; do
	seeker /dev/sda > /tmp/seeker.tmp
	seeks="`grep '^Results' /tmp/seeker.tmp | awk '{ print $2 }'`"
	accesstime="`grep '^Results' /tmp/seeker.tmp | awk '{ print $4 }'`"
	bytes=`expr ${seeks} \* 4096`
	kbytes=`expr ${bytes} \/ 1024`
	echo "${i}: ${seeks} seeks/second, ${accesstime} ms, ${kbytes} KB/sec"
	rm -f /tmp/seeker.tmp
done

exit 0
