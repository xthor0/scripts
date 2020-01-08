#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Find EC2 instance by IP address."
	echo "Usage:

`basename $0` -p <aws profile> -i <ip address>"
	exit 255
}

# get command-line args
while getopts "p:i:" OPTION; do
	case $OPTION in
		p) profile=${OPTARG};;
        i) ipaddr=${OPTARG};;
		*) usage;;
	esac
done

# verify command-line args
if [ -z "${profile}" -o -z "${ipaddr}" ]; then
	usage
fi

# get a list of regions
regions=$(aws --region us-west-2 ec2 describe-regions --profile ${profile} --output text | awk '{ print $4 }')

# ensure the regions variable is not empty
if [ -z "${regions}" ]; then
    echo "Unable to retrieve list of regions. Check output above."
    exit 255
fi

# loop through the regions and look for an ip
for region in ${regions}; do
    echo "Region: ${region}"
    aws --profile ${profile} ec2 describe-instances --filter Name=private-ip-address,Values=${ipaddr} --query 'Reservations[].Instances[].InstanceId' --output text --region ${region}
done