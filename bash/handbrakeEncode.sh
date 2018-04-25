#!/bin/bash

outputDir=/media/2nd\ HD/Encodes/Completed
inputDir=/media/2nd\ HD/Rips/Process
completeDir="/media/2nd HD/Rips/Completed"
prowl=$HOME/Dropbox/projects/scripts/prowl.pl

# make sure directories exist
for dir in "${inputDir}" "${outputDir}" "${completeDir}"; do
	if [ ! -d "${dir}" ]; then
		echo "Error -- directory does not exist: $dir"
		exit 255
	fi
done

# mark the start date and time
startDate="$(date)"
echo "Encode started: ${startDate}"

# process each file in inputDir
find "${inputDir}" -type f | while read file; do
	echo "Input file: ${file}"

	# create variable for output filename
	stripPath=$(basename "${file}")
	outputFileName="${outputDir}/${stripPath%.*}.mp4"

	# does the output file already exist?
	if [ -f "${outputFileName}" ]; then
		echo "Output file already exists: ${outputFileName} -- skipping."
	else
		echo "Output file: ${outputFileName}"

		# process file with Handbrake -- don't ask why we have to pipe nothing to the script
		echo "" | HandBrakeCLI -i "${file}" -o "${outputFileName}" -f mp4 -4 --decomb --deinterlace --loose-anamorphic  --modulus 16 -e x264 -q 20 --vfr -a 1,1 -E faac,copy:ac3 -6 dpl2,auto -R Auto,Auto -B 160,0 -D 0,0 --gain 0,0 --audio-copy-mask none --audio-fallback ffac3 -m -x b-adapt=2:rc-lookahead=50 2>/dev/null

		# move the file to a completed directory
		mv "${file}" "${completeDir}"
		echo "${file} processed successfully."
		echo "===="
	fi
done

# mark the end date
endDate="$(date)"
echo "Encode completed: ${startDate}"

# if prowl.pl is found, use it to push a notification
if [ -x "${prowl}" ]; then
	"${prowl}" -apikey=fb18cb558102482e883ac76ba05a3c1b00212e96 -application=HandbrakeCLI -event="Encode started ${startDate}" -notification="Handbrake Encode Complete at ${endDate}" -priority=0
fi

# exit :)
exit 0
