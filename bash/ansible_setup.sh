#!/bin/bash

# might need to tweak this for debian/ubuntu detection at some point

sudo dnf install ansible git

scp pajak.xthorsworld.com:SSH/id_rsa

mv id_rsa .ssh && chmod 600 .ssh/id_rsa

ssh-keygen -y -f .ssh/id_rsa > .ssh/id_rsa.pub

# really should merge this to main someday, no?
ansible-pull -U https://github.com/xthor0/ansible.git -K -C debian-openbox playbooks/workstation.yml
