#!/usr/bin/env python

import salt.client
local = salt.client.LocalClient()
# local.cmd('*', 'cmd.run', ['whoami'])
val = local.cmd('*', 'test.ping')

print(val)

