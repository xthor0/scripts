#!/bin/bash -l

MESSAGE=$*

if [ -z "$MESSAGE" ]; then
	echo "You need to pass at least one argument. Dumbass."
	exit 255
fi

# Terminal columns
COLUMNS=$(tput cols)

# functions
function failed {
	tput sc
	tput cuf $COLUMNS
	tput cub 10
	echo -n "[ "
	tput setaf 1; tput bold
	echo -n "FAILED"
	tput sgr0
	echo -n " ]"
	tput rc
	echo
}

function passed {
	tput sc
	tput cuf $COLUMNS
	tput cub 6
	echo -n "[ "
	tput setaf 2; tput bold
	echo -n "OK"
	tput sgr0
	echo -n " ]"
	tput rc
	echo
}

echo -n "$MESSAGE"
failed

echo -n "$MESSAGE"
passed

exit 0
