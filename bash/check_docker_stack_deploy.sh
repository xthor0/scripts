#!/bin/bash

# we expect a single argument - the name of the service to deploy
if [ -z "$1" ]; then
    echo "$(basename $0) expects one argument: the name of the docker stack!"
    exit 255
fi

# how long do we sleep between checks, in seconds?
SLEEP=10

# how many attempts do we make?
ATTEMPTS=30

# set a CLI variable that includes the certs and the host to connect to
DOCKERCLI="/bin/docker --tlsverify --tlscacert=$HOME/.docker/ca.pem --tlscert=$HOME/.docker/cert.pem --tlskey=$HOME/.docker/key.pem -H 10.13.0.29:2376"

# make sure your Docker CLI is functional
${DOCKERCLI} version >& /dev/null
if [ $? -ne 0 ]; then
    echo "The Docker CLI is not working correctly on this Jenkins master! Exiting."
    exit 255
fi

# make sure we HAVE a stack by the name we're going to look for in the loop below...
${DOCKERCLI} stack ls --format "{{.Name}}: {{.Services}}" | grep -q $1
if [ $? -eq 1 ]; then
    echo "Could not find a Docker stack named $1 -- exiting!"
    exit 255
fi

# start a loop
ATTEMPT=0
while true; do
    ${DOCKERCLI} service ls -f "name=${1}_" --format "{{.ID}}: {{.Replicas}}" | grep -q ": 0\/"]
    if [ $? -eq 0 ]; then
        # there are still services showing replcas with 0/??? - so we retry
        if [ $ATTEMPT -lt 30 ]; then
            let ATTEMPT+=1
            sleep $SLEEP
        else
            # we've exceeded our attempt threshold - time to exit
            echo "Docker stack failed deploying $1 -- There are still services showing 0 replicas!"
            exit 255
        fi
    else
        # service should be up and running!
        echo "Docker successfully deployed stack $1 -- exiting!"
        break
    fi
done 

# fin
exit 0
