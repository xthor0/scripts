#!/bin/bash

# how long do we sleep between checks, in seconds?
SLEEP=10

# how many attempts do we make?
ATTEMPTS=30

# IP address of docker swarm master
MASTER=10.13.0.29

# URL of ECR
ECR_URL="https://306830492833.dkr.ecr.us-west-2.amazonaws.com"

# set a CLI variable that includes the certs and the host to connect to
DOCKERCLI="/bin/docker --tlsverify --tlscacert=$HOME/.docker/ca.pem --tlscert=$HOME/.docker/cert.pem --tlskey=$HOME/.docker/key.pem -H ${MASTER}:2376"

# make sure your Docker CLI is functional
${DOCKERCLI} version >& /dev/null
if [ $? -ne 0 ]; then
    echo "There was a problem either with the Docker CLI or the swarm master - exiting."
    exit 255
fi

# grab ECR token
ECR_TOKEN=$(/opt/awscli/bin/aws ecr get-login | awk '{ print $6 }')

# authenticate swarm to ECR
echo ${ECR_TOKEN} | ${DOCKERCLI} login -u AWS --password-stdin ${ECR_URL}
if [ $? -ne 0 ]; then
    echo "Error authenticating Docker Swarm to Amazon ECR - exiting!"
    exit 255
fi

# if this stack is already deployed, it's going to change how we check for successful deployment
${DOCKERCLI} stack ls --format "{{.Name}}: {{.Services}}" | grep -q ${TAG_NAME}
if [ $? -eq 0 ]; then
    EXISTING="yes"

    # write some data to a temp file so we can compare the output later
    STATUS_FILE=$(mktemp)
    ${DOCKERCLI} service ls -f "name=${TAG_NAME}_" --format "{{.Name}}" | while read service_name; do
        echo -n "${service_name}~" >> ${STATUS_FILE}
        ${DOCKERCLI} service inspect --format='{{.Meta.UpdatedAt}}' ${service_name} >> ${STATUS_FILE}
    done
fi

# deploy service
${DOCKERCLI} stack deploy --with-registry-auth --compose-file docker-compose.yml ${TAG_NAME}

# the type of check we do to make sure the service is up and running differs - depending on if this is a stack that's up and running already
if [ -z "${EXISTING}" ]; then
    # now we start a loop waiting for the stack to deploy
    ATTEMPT=0
    while true; do
        ${DOCKERCLI} service ls -f "name=${TAG_NAME}_" --format "{{.ID}}: {{.Replicas}}" | grep -q ": 0\/"
        if [ $? -eq 0 ]; then
            # there are still services showing replcas with 0/??? - so we retry
            if [ $ATTEMPT -lt $ATTEMPTS ]; then
                echo "Waiting for Docker stack to deploy (attempt ${ATTEMPT} of ${ATTEMPTS}) - checking again in ${SLEEP} seconds."
                let ATTEMPT+=1
                sleep $SLEEP
            else
                # we've exceeded our attempt threshold - time to exit
                echo "Docker stack failed deploying ${TAG_NAME} -- There are still services showing 0 replicas!"
                exit 255
            fi
        else
            # service should be up and running!
            echo "Docker successfully deployed stack ${TAG_NAME} -- exiting!"
            break
        fi
    done 
else
    # this loop is slightly different - we're looking for a meta UpdatedAt value to compare to make sure that our service has updated properly
    ATTEMPT=0
    while true; do
        UPDATED=0
        SVCS=0
        cat ${STATUS_FILE} | while read line; do
            # break out line into variables
            service_name=$(echo $line | cut -d \~ -f 1)
            update_date=$(echo $line | cut -d \~ -f 2)

            # it's always possible a service has been removed from the stack, so let's make sure it's still alive
            ${DOCKERCLI} service ls -f "name=${TAG_NAME}_" --format "{{.Name}}" | grep -q ${service_name}
            if [ $? -eq 0 ]; then
                let SVCS+=1
                # get current update_date from Docker
                current_update_date=$(${DOCKERCLI} service inspect --format='{{.Meta.UpdatedAt}}' ${service_name})
                if [ "${current_update_date}" != "${update_date}" ]; then
                    echo "Date of update before deploy: ${update_date}"
                    echo "Date of update after deploy: ${current_update_date}"
                    echo "Docker service ${service_name} has updated successfully."
                    let UPDATED+=1
                fi
            fi
        done

        # let's check the results of the loop
        if [ ${SVCS} -eq ${UPDATED} ]; then
            echo "All Docker services for ${TAG_NAME} have been updated."
            break
        else
            echo "Still waiting on Docker services for ${TAG_NAME} to update (${UPDATED} services updated of ${SVCS}) - sleeping 2 seconds."
            sleep 2
        fi
    done
fi

# I don't know if this will always work - but for letters, we can do a HTTP check to make sure the container is responding to requests.
# put this in a loop, check every second for 60 seconds
HTTP_ATTEMPT=0
HTTP_MAX_ATTEMPTS=30
while true; do
    echo "Checking ${URL} for HTTP return code 200..."
    HTTP_CODE=$(curl --write-out %{http_code} --silent --output /dev/null ${URL})
    if [ ${HTTP_CODE} -eq 200 ]; then
        echo "Got HTTP code 200 from ${URL} -- deployment was a success!"
        break
    else
        if [ ${HTTP_ATTEMPT} -ge ${HTTP_MAX_ATTEMPTS} ]; then
            echo "Maximum attempts reached - last HTTP return code was ${HTTP_CODE}"
            exit 255
        else
            let HTTP_ATTEMPT+=1
            echo "HTTP return code is ${HTTP_CODE} - sleeping 2 seconds..."
            sleep 2
        fi
    fi
done

# cleanup
rm -f ${STATUS_FILE}

# fin
exit 0
