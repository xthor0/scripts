#!/bin/bash

startDate=$(date)

currentLog=$(mktemp)

# display usage
function usage() {
	echo "`basename $0`: Encode a single file using Handbrake"
	echo "Usage:

`basename $0` -i <input filename> -o <output directory>"
	exit 255
}

# get command-line args
while getopts "i:o:" OPTION; do
	case $OPTION in
		i) inputfile="$OPTARG";;
		g) outputdir="$OPTARG";;
		*) usage;;
	esac
done


# verify command-line arguments
if [ -z "$inputfile" -o -z "$outputdir" ]; then
	usage
fi

# verify inputfile exists
if [ -f "$inputfile" ]; then
	if [ -d "$outputdir" ]; then
		newfile=$(basename "$inputfile" .mkv)
		echo "Encoding ${inputfile} to ${outputdir}/${newfile}.m4v..."
		start=$(date +%s)
		echo | HandBrakeCLI -Z 'High Profile' -m -i "${inputfile}" -o "encode/${newfile}.m4v" 2> $currentLog
		end=$(date +%s)
		diff=$(($start-$end))
		echo "$(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
		endDate=$(date)

		# pushover notification
		curl -s \
		  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
		  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
		  --form-string "message=Handbrake encode completed <> Started: $startDate :: Ended: $endDate" \
		  https://api.pushover.net/1/messages.json

		echo "Don't forget to delete your temp log file - $currentLog"
	else
		echo "$outputdir is not a directory or does not exist!"
		exit 255
	fi
else
	echo "$inputfile does not exist - exiting!"
	exit 255
fi

# fin
exit 0
