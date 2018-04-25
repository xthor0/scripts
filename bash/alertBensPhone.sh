#!/bin/bash

nma=$HOME/Dropbox/projects/scripts/nma.pl

if [ ! -x $nma ]; then
	echo "Missing nma.pl - can't function without it."
	exit 255
fi

# for reference
# ~/Dropbox/projects/scripts/nma.pl -apikey=e7b0be8e783a874d652c501c5e7f976c21c7a16e8d6e80ef -notification="Test 2 from Ben's media server, bitch" -event="handbrake"

# display usage
function usage() {
        echo "`basename $0`: send Ben's Android phone a message."
        echo "Usage:

`basename $0` -t \"text of alert goes here\" -e <name of event>

the quotes are required!"
        exit 255
}

# get command-line args
while getopts "t:e:" OPTION; do
        case $OPTION in
                t) text="$OPTARG";;
		e) event="$OPTARG";;
                *) usage;;
        esac
done

# verify arguments
if [ -z "$text" ]; then
	usage
fi

if [ -z "$event" ]; then
	usage
fi

# do it to it mofo
$nma -apikey=e7b0be8e783a874d652c501c5e7f976c21c7a16e8d6e80ef -notification="$text" -event="$event"

exit 0
