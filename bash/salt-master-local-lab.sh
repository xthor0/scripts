#!/bin/bash

# create salt master config file
cat > /etc/salt/master << EOF
file_roots:
  base:
    - /srv/salt/top
    - /srv/salt/states

pillar_roots:
  base:
    - /srv/salt/pillar

reactor:
  - 'salt/auth':
    - '/srv/salt/reactor/auto_accept_key.sls'

log_level: info
EOF

# create reactor directory
mkdir -p /srv/salt/reactor

# create reactor to auto accept key
cat > /srv/salt/reactor/auto_accept_key.sls << EOF
reactor__cloud_created__master_add_minion:
  wheel.key.accept:
    - match: {{ data['id'] }}
EOF

# make salt-master run at boot
systemctl enable salt-master
