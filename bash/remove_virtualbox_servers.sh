#!/bin/bash

# this isn't super automated, but I'm keeping it around so I remember the easy way to remove temp VMs I spin up for
# Salt development

for node in docker-swarm0{1..5}; do
  echo ${node}
  vboxmanage controlvm ${node} poweroff && vboxmanage unregistervm ${node} --delete
  echo
done

exit 0
