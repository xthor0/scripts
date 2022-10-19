#!/usr/bin/env python3

import json
import logging
import argparse
import pprint
import tabulate
import datetime

import boto3
from botocore.exceptions import ClientError

'''
python -m venv ./venv
source ./venv/bin/activate
pip install boto3 tabulate
# because Ben always forgets
'''

# these have to match the AWS profile configured - see ~/.aws/config or
accounts = [ "common-nonprod", "common-prod", "shared", "data-prod", "data-nonprod" ]
regions = [ "us-east-1", "us-east-2", "us-west-1", "us-west-2" ]

# logger config
logger = logging.getLogger()
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s: %(levelname)s: %(message)s')


def load_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-n', '--norotate', help="Only show keys that are not set to rotate", action='store_true')
    args = parser.parse_args()
    return args


def table_output(results):
    header = results[0].keys()
    rows = [x.values() for x in results]
    print(tabulate.tabulate(rows, header))


def list_kms_keys(max_items, args):
    """
    Gets a list of all KMS keys.
    """
    try:
        # make an array to store the results
        key_list = []

        # get all the keys
        kms_key_list = kms_client.list_keys()

        # extract the keyID (which we'll need to look up rotation status and alias)
        for key in kms_key_list['Keys']:
            keyid = key['KeyId']

            # we have to describe it to find out when it was created and who manages it
            key_info = kms_client.describe_key(KeyId=keyid)

            # if this is NOT customer-managed, skip it
            managed_by = key_info['KeyMetadata']['KeyManager']
            # logger.info("DEBUG: key is managed by {}".format(managed_by))
            if managed_by == "AWS":
                # skip this record
                continue

            # get the creation date and turn it into a string for nice formatting later
            creationdate = key_info['KeyMetadata']['CreationDate']
            created = creationdate.strftime("%Y/%m/%d %H:%M:%S")

            # look up key alias now that we have a keyID
            aliases = kms_client.list_aliases(KeyId=keyid)
            aliasCount = len(aliases['Aliases'])
            if aliasCount == 1:
                alias = aliases['Aliases'][0]['AliasName']
            elif aliasCount >= 2:
                alias = "Error"
            else:
                alias = "N/A"

            # and finally let's get the rotation status of the key
            rotationStatus = kms_client.get_key_rotation_status(KeyId=keyid)
            rotation = rotationStatus['KeyRotationEnabled']

            if args.norotate:
                # logger.info("DEBUG: args.norotate is TRUE -- this record's rotation status is {} (type {})".format(rotation, type(rotation)))
                if rotation:
                    # do not load this record into the keyObj, thus filtering it out
                    # we will still get keys with the Error status, but that's OK
                    continue
                
            keyObj = { 'Account': account, 'Region': region, 'KeyID': keyid, 'Alias': alias, 'Created': created, 'Rotation': rotation }

            # needs more work, but let's see if this works
            key_list.append(keyObj)

    except ClientError:
        logger.exception('Could not list KMS Keys.')
        raise
    else:
        return key_list


if __name__ == '__main__':
    args = load_args()
    # Constants
    MAX_ITEMS = 99
    key_list = []
    for account in accounts:
        for region in regions:
            logger.info('Establishing session for AWS account {} in region {}'.format(account, region))
            session = boto3.Session(profile_name=account, region_name=region)
            kms_client = session.client('kms')

            logger.info('Retrieving KMS keys...')
            kms_keys = list_kms_keys(MAX_ITEMS, args)
            for key in kms_keys:
                key_list.append(key)
            logger.info('Completed.')

    # display results as a pretty table
    table_output(key_list)
