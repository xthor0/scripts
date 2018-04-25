#!/bin/bash

startDate=$(date)

if [ ! -d encode ]; then
	mkdir encode
	if [ $? -ne 0 ]; then
		echo "Unable to create encode output directory. Exiting..."
		exit 255
	fi
fi

batchLog=$(mktemp)
currentLog=$(mktemp)
find . -maxdepth 1 -type f -iname "*.mkv" | while read inputfile; do
	newfile=$(basename "$inputfile" .mkv)
	echo "Processing ${inputfile} to $(pwd)/encode/${newfile}.m4v..."
	start=$(date +%s)
	echo | HandBrakeCLI -Z 'High Profile' -m --start-at duration:22 -i "${inputfile}" -o "encode/${newfile}.m4v" 2> $currentLog
	end=$(date +%s)
	cat $currentLog >> $batchLog
	diff=$(($start-$end))
	echo "$(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
	#cp "$HOME/Rips/encode/${newfile}.m4v" /mnt/media/Movies
	#mv "${inputfile}" $HOME/Rips/completed
done

endDate=$(date)

# send prowl notification
#$HOME/Dropbox/projects/scripts/prowl.pl -apikey=fb18cb558102482e883ac76ba05a3c1b00212e96 -application=HandBrakeCLI -event="Handbrake Encode Completed" -notification="Started: $startDate :: Ended: $endDate" -priority=-2

# nma notification
#nma.sh HandbrakeCLI "Handbrake Law & Order encode completed" "Started: $startDate :: Ended: $endDate" 0

# pushover notification
curl -s \
  --form-string "token=aJDLy7G17EXCAfeqV2s2ujGjnT63xY" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Handbrake encode completed <> Started: $startDate :: Ended: $endDate" \
  https://api.pushover.net/1/messages.json

echo "Don't forget to delete your temp files -- $batchLog and $currentLog"

exit 0
