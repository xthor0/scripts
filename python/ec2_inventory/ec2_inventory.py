#!/usr/bin/env python3

import boto3
import argparse
import pprint
import re
import json 
import yaml
import sys

# these have to match the AWS profile configured - see ~/.aws/config or
accounts = [ "common-nonprod", "common-prod", "shared", "data-prod", "data-nonprod" ]
regions = [ "us-east-1", "us-east-2", "us-west-1", "us-west-2" ]

parser = argparse.ArgumentParser()
parser.add_argument('-r', '--running', help='list ONLY running instances', action='store_true')
parser.add_argument('-q', '--quiet', help='suppress loading information (use this if you want to pipe to file or jq)', action='store_true')
parser.add_argument('-u', '--output', help='output in one of the following: json|yaml', choices=['json', 'yaml'])
group = parser.add_mutually_exclusive_group()
group.add_argument('-o', '--os', help='filter by OS tag (specify "none" to show only instances with no OS tag)')
group.add_argument('-n', '--name', help='filter by name tag (specify "none" to show only instances with missing name tag)')
group.add_argument('-e', '--env', help='filter to specified env tag (specify "none" for instances missing env tag)')
group.add_argument('-s', '--sclass', help='filter to specified ServerClass tag tag (specify "none" for instances missing ServiceClass tag)')
group.add_argument('-t', '--type', help='filter to specified instance type')
args = parser.parse_args()

# function to filter instances based on arguments passed
def filterInstances(inputObj):
    def searchInstance(obj):
        def findStr(string, haystack):
            search = re.search(string, haystack, re.IGNORECASE)
            if (search):
                return True
            else:
                return False

        search = False
        if args.name is not None:
            search = findStr(args.name, obj['name'])

        if args.os is not None:
            search = findStr(args.os, obj['os'])
        
        if args.sclass is not None:
            search = findStr(args.sclass, obj['class'])

        if args.env is not None:
            search = findStr(args.env, obj['env'])
        
        if args.type is not None:
            search = findStr(args.type, obj['instancetype'])

        if search:
            return obj
        else:
            return False

    filtered_instances = []

    for obj in inputObj:
        record_match = searchInstance(obj)
        if(record_match):
            filtered_instances.append(record_match)

    return filtered_instances

# function to handle output
def printResults(inputObj):
    if args.output is not None:
        if args.output == 'json':
            print(json.dumps(inputObj))
        elif args.output == "yaml":
            print(yaml.dump(inputObj))
    else:
        print("{: >15} {: >10} {: >25} {: >40} {: >15} {: >15} {: >12} {: >35} {: >16} {: >16} {: >12}".format("Account",
                                                                                                               "Region",
                                                                                                               "Instance ID",
                                                                                                               "Name",
                                                                                                               "Creation Date",
                                                                                                               "Instance Type", "Application", "EKS Cluster", "Private IP", "Public IP", "State"))
        print("=" * 233)
        for instance in inputObj:
            print("{account: >15} {region: >10} {instanceid: >25} {name: >40} {creation_date: >15} {instancetype: >15} {application: >12} {ekscluster: >35} {privateip: >16} {publicip: >16} {state: >12}".format(**instance))
        print("\nTotal instances found: {}".format(len(inputObj)))

# load all instance information from AWS API
def loadInstances(is_running):
    # an array to store all this fun in
    instances = []

    # let the user know we're actually doing something, because API calls can be slow
    if not args.quiet:
        print("Loading EC2 information from AWS accounts ", end='', flush=True)

    for account in accounts:
        # letting the user know which account we're loading from
        if not args.quiet:
            print(":: {} ".format(account), end='', flush=True)

        for region in regions:
            session = boto3.Session(profile_name=account, region_name=region)
            ec2 = session.client('ec2')

            response = ec2.describe_instances()

            for r in response['Reservations']:
                for i in r['Instances']:
                    state = i['State']['Name']
                    tag_name = "None"
                    tag_application = "None"
                    tag_workspace = "None"
                    tag_cluster = "N/A"
                    try:
                        for tag in i['Tags']:
                            if tag['Key'] == "Name":
                                tag_name = tag['Value']
                            if tag['Key'] == "application":
                                tag_application = tag['Value']
                            if tag['Key'] == "workspace":
                                tag_workspace = tag['Value']
                            if tag['Key'] == "eks:cluster-name":
                                tag_cluster = tag['Value']
                    except KeyError:
                        pass
                    
                    private_ip = "N/A"
                    public_ip = "N/A"
                    try:
                        private_ip = i['PrivateIpAddress']
                        public_ip = i['PublicIpAddress']
                    except KeyError:
                        pass

                    # find instance creation date, sort of
                    if state != 'terminated':
                        volumes = ec2.describe_volumes(
                            Filters=[{'Name':'attachment.instance-id','Values':[i['InstanceId']]}]
                        )
                        creation_date = volumes['Volumes'][0]['CreateTime'].strftime("%Y.%d.%m")
                    else:
                        creation_date = "N/A"

                    objDict = {
                        'account': account,
                        'region': region,
                        'instanceid': i['InstanceId'],
                        'name': tag_name,
                        'application': tag_application,
                        'workspace': tag_workspace,
                        'ekscluster': tag_cluster,
                        'instancetype': i['InstanceType'],
                        'privateip': private_ip,
                        'publicip': public_ip,
                        'state': state,
                        'creation_date': creation_date
                    }

                    # if specified, filter out instances that are NOT in a running state
                    if(is_running):
                        if(objDict['state'] == 'running'):
                            instances.append(objDict)
                    else:
                        instances.append(objDict)

    # let the user know we're done loading now
    if not args.quiet:
        print(" ==> OK!\n")
    return instances

## main
instances = loadInstances(args.running)
if args.os is not None or args.name is not None or args.env is not None or args.sclass is not None or args.type is not None:
    filtered_instances = filterInstances(instances)
    printResults(filtered_instances)
else:
    printResults(instances)