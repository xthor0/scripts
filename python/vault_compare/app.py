import os

import hvac

import argparse

# we need to know a few things - like, where's my vault? and where's

# Using plaintext
client = hvac.Client(url='http://localhost:8200', token=os.environ['VAULT_TOKEN'])

# these examples may prove useful in the future, but we're not using them right now
# Using TLS
# client = hvac.Client(url='https://localhost:8200')

# Using TLS with client-side certificate authentication
# client = hvac.Client(url='https://localhost:8200',
#                     cert=('path/to/cert.pem', 'path/to/key.pem'))

# write
client.write('secret/foo', baz='bar', lease='1h')

# read
print(client.read('secret/foo'))

# delete
client.delete('secret/foo')
