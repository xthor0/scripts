#!/bin/bash

# set killAlarm
echo 0 > $HOME/killAlarm

# let's grab a random song...
music=$(find $HOME/Music/ -type f | sort -R | tail -n1)

# set the volume to something that won't make me jump out of my skin when it goes off...
volume=2200
amixer -q set PCM -- -${volume}

# start playing the song - kick mpg123 to the background
mpg123 -q "${music}" &
c_pid=$!

# start raising the volume slowly...
volLimit=1000
while [ $volume -ge ${volLimit} ]; do
        let volume-=10
        amixer -q set PCM -- -${volume}

        # check to see if we should stop alarm...
        if [ $(cat $HOME/killAlarm) -eq 1 ]; then
                kill $!
                break
        fi

        sleep 2
done

# TODO: 1) get a button, and require that it is pushed to shut this up
# 2) this script should look for input for that button otherwise it will start over completely

exit 0
