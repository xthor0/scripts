#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Specify a hostname or IP, e.g. $(basename $0) 10.200.99.5"
    exit 255
fi

retval=0
while [ $retval -eq 0 ]; do
    nmap -oG - -Pn -p 22 --open emailgen.xthorsworld.com | grep -q Ports
    if [ $? -eq 1 ]; then
        echo "Host $1 not booted yet... sleeping..."
        sleep 5
    else
        echo "Host $1 has booted."
        retval=1
    fi
done
