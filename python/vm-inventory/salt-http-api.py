#!/usr/bin/env python

import requests
import argparse
import getpass
import pprint


def saltcommand(url, username, password, target):
    """ execute a command on the Salt master and return a JSON object """

    session = requests.Session()
    session.verify = False

    # when logging in, hit /login instead of just url
    loginurl = "{}/{}".format(url, "login/")
    print(loginurl)

    post = session.post(loginurl, json={
        'username': username,
        'password': password,
        'eauth': 'pam',
    })

    if post.status_code == 200:
        # resp = session.post(url, json=[{
        #    'client': 'local',
        #    'tgt': target,
        #    'fun': 'grains.items',
        #    'expr_form': 'ipcidr'
        # }])

        resp = session.post(url, json=[{
            'client': 'local',
            'tgt': target,
            'fun': 'grains.item',
            'arg': ['id']
        }])

        jsonobj = resp.json()['return']
        return jsonobj
        #return resp
    else:
        return False


def getpassword(url):
    """ get the password to authenticate with in a secure fashion. """
    try:
        prompt="Please enter your password for {}: ".format(url)
        password = getpass.getpass(prompt=prompt)
        return password
    except Exception as error:
        print('ERROR', error)
        exit(255)


def parsesaltdata(data):
    """ parse what we got back from the API call, and store it in an easy-to-read list """

    results = []
    for listitem in data:
        for miniondata in listitem.iteritems():
            # print("Minion Name: {}".format(miniondata[0]))
            # print("Minion IP Address: {}".format(miniondata[1]['ipv4'][0]))
            # print("Minion OS: {}".format(miniondata[1]['oscodename']))
            # print("============================================")
            record = {"name": miniondata[0], "ipaddr": miniondata[1]['ipv4'][0], "os": miniondata[1]['oscodename']}
            results.append(record)

    if len(results) is 0:
        return False
    else:
        return results


def main():
    """
    App to use the Salt HTTP API
    """

    # get arguments from command-line
    parser = argparse.ArgumentParser()
    parser.add_argument('-u', '--username', required=True, help='username to authenticate with')
    parser.add_argument('-H', '--hostname', required=True, help='hostname running Salt API')
    parser.add_argument('-i', '--ipaddr', required=True, help='Return minion grains for this IP address')
    args = parser.parse_args()

    # build URL to connect to
    url = "https://{}:8000".format(args.hostname)

    # password
    password = getpassword(url)

    data = saltcommand(url, args.username, password, args.ipaddr)
    pprint.pprint(data)
    exit(9)
    if data is False:
        print("Unable to login to {} - exiting.".format(url))
        exit(9)
    else:
        results = parsesaltdata(data)
        if results is False:
            print("No results found for IP {}".format(args.ipaddr))
        else:
            for minion in results:
                print("Found minion with IP address {ipaddr} named {name}".format(**minion))


# Start program
if __name__ == "__main__":
    main()

