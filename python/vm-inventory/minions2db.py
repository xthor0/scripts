#!/usr/bin/env python

import salt.client
import re
import redis

local = salt.client.LocalClient()
# local.cmd('*', 'cmd.run', ['whoami'])
saltresult = local.cmd('*', 'grains.item', ['ipv4', 'oscodename', 'serialnumber'])

# here's where we'll store everything
result = []

#print(result)
for minion, grains in saltresult.iteritems():
    minionrecord = {}
    print(minion)
    print('===============')
    for grain, details in grains.iteritems():
        print('Grain: {} ==>'.format(grain))
        if grain == "ipv4":
            counter = 0
            item = {}
            for val in details:
                if val == "127.0.0.1":
                    continue
                counter += 1
                print('IP Address #{}: {}'.format(counter, val))
                itemname = 'ipaddr' + str(counter)
                item.update({itemname: val})
        elif grain == 'serialnumber':
            # this is gonna take some work
            # here's some examples of how this information is presented
            # salt: VMware-42 36 15 20 27 a1 d6 f4-ef f8 3e b6 13 ac c8 a9
            # vmware: 42361520-27a1-d6f4-eff8-3eb613acc8a9
            # for reference - the vmware information is stored as obj.config.uuid
            # I need Python to convert the salt value to match the VMware value
            newsn = re.sub(' ', '', details)
            if re.match('^VMware-', newsn) is None:
                item = {grain: newsn}
            else:
                newsn = re.sub('^VMware-', '', newsn)
                item = {grain: newsn}
        else:
            print('Value: {}'.format(grain, details))
            item = {grain: details}
        print(item)
        minionrecord.update(item)
    print('\n')
    record = {minion: minionrecord}
    result.append(record)

# results displayed in the format they'll go into a database
# connect to Redis instance
r = redis.Redis('localhost')
for item in result:
    for minion, details in item.iteritems():
        print(minion)
        print(details)
        #for grain in details:
            #print("{} : {}".format(name, grain))
            #print(grain)


