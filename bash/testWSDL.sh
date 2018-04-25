#!/bin/sh

if [ -z "$1" ]; then
	echo "Must specify loops to run."
	exit 255
fi

count=$1
fail=0
success=0
for i in `seq 1 $count`; do
	wget http://ulm.datamark.com/wsdls/production-iscompanies.wsdl > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		let fail+=1
	else
		hash="`sha1sum production-iscompanies.wsdl | awk '{print $1}'`"
		correctHash="0479a1b31f5292dfa33db0d8270defe12726b7c2"
		if [ "$hash" == "$correctHash" ]; then
			let success+=1
		else
			let fail+=1
		fi
	fi

	rm -f production-iscompanies.wsdl
	echo "Count: Failed: $fail Success: $success"
done

exit 0
