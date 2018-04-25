#!/bin/bash

host=$1
files=$HOME/asdm

if [ -z "$host" ]; then
	echo "You must specify the IP address of the ASDM instance, i.e. $0 10.0.0.1"
	exit 255
fi

if [ ! -f $files/$host.jnlp ]; then
	echo "Error: Can't find $files/$host.jnlp!"
	exit 255
fi

javaws $files/$host.jnlp &

exit 0
