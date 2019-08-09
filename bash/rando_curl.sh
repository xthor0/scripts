#!/bin/bash

echo "CURL FOR LIFE!"
echo
echo "Press CTRL-C to exit this shit."

while true; do
    sleep=$(($RANDOM % 120))
    stamp=$(date +%s)
    echo "Date stamp: ${stamp}"
    curl -s 10.187.88.106/${stamp} >& /dev/null
    if [ $? -eq 0 ]; then
        echo "Sleeping ${sleep} seconds..."
        sleep ${sleep}
    else
        echo "Curl exited badly, so we're exiting."
        exit 255
    fi
done

# THIS IS THE SCRIPT THAT NEVER ENDS!