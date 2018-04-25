#!/bin/bash

#inputFileName=`grep ^Processing /var/log/stingray/customer_imports/WAL0006_walden_lead_import.log | tail -n 20 | awk '{ print $2 }'`
inputFileName=$(find /var/tmp/walden -type f)

if [ -n "${inputFileName}" ]; then
	foundFile=0
	for inputfile in ${inputFileName}; do
		if [ -f "${inputfile}" ]; then
			records=`wc -l ${inputfile} | awk '{ print $1 }'`
			echo "File being processed: ${inputfile} -- Records: ${records}"
			foundFile=1
			break
		fi
	done

	if [ ${foundFile} -eq 0 ]; then
		echo "None of the source files processed by Walden Status Import still exist."
		echo "This is a good thing -- all processing has completed."
		exit 0
	fi
else
	echo "Could not determine input file name from /var/log/stingray/customer_imports/WAL0006_walden_lead_import.log."
	exit 255
fi

# monitor progress
sleeptime=10
loop=0
total=0
average=0
completeddiff=0
lastcompleted=0
printf "[%-17s] %8s / %9s / %8s / %3s / %3s\n" Date Completed Total Processed Avg RPS
while true; do
	# increment loop counter
	let loop+=1

	# get progress information
	leadid=`grep Onyx /var/log/stingray/customer_imports/WAL0006_walden_lead_import.log | tail -n 1 | awk '{ print $10 }' | tr -d \[\] | tr -d [:cntrl:]`
	completed=`cat -n ${inputfile} | grep $leadid | awk '{ print $1 }'`
	date=$(date +%D)
	time=$(date +%T)

	# get some time metrics
	if [ ${lastcompleted} -eq 0 ]; then
		completeddiff=0
	else
		completeddiff=$(expr ${completed} - ${lastcompleted})
	fi

	let total+=${completeddiff}
	average=$(expr ${total} / ${loop})
	rps=$(expr ${average} / ${sleeptime})

	# store completed var for next run for comparison
	lastcompleted=${completed}

	# output to screen
	#echo "$date $time: $completed / $records"
	printf "[%s %s] %9d / %9d / %9d / %3d / %3d\n" $date $time $completed $records $completeddiff $average $rps

	# take a nap
	sleep ${sleeptime}
done
