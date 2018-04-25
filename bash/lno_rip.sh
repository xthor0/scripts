#!/bin/bash

# find season # - should be last character of CWD
season="${PWD: -1}"
if ! [[ "$season" =~ ^[0-9]+$ ]]; then
	echo "Sorry - $season is not a number"
	exit 255
fi

# output disc information to temp directory
discinfo=$(mktemp)
makemkvcon --progress=-stdout -r info dev:/dev/sr0 > $discinfo
# need to put logic here about checking disc again if makemkvcon can't read the disc

# find all tracks that are longer than 20 mins but shorter than an hour


# I only have 2 seasons left - maybe it's not worth scripting NOW...
