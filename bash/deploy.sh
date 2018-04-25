#!/bin/bash

dotfiles="${HOME}/git/scripts/dotfiles"

# an unnecessary edit...

# argument is required
if [ -z "$1" ]; then
	echo "You must pass a hostname as an argument."
	echo "You wrote this script, you should know that..."
	exit 255
fi

# push SSH key
ssh-copy-id ${1}
if [ $? -ne 0 ]; then
	echo "Error: Unable to copy SSH key to ${1}."
	exit 255
fi

# push custom .bashrc
scp "${dotfiles}/bashrc-remote" ${1}:.bashrc
if [ $? -ne 0 ]; then
	echo "Error: Unable to copy bashrc-remote to ${1}:.bashrc..."
	exit 255
fi

echo "Deploy complete."
exit 0
