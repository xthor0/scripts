#!/bin/bash

# this script expects the minions to be named correctly, and the snap to be named Clean

for id in 1 2 3; do
  vmrun stop ~/Documents/Virtual\ Machines.localized/salt-minion${id}.vmwarevm/ hard
  vmrun revertToSnapshot ~/Documents/Virtual\ Machines.localized/salt-minion${id}.vmwarevm/ Clean
  vmrun start ~/Documents/Virtual\ Machines.localized/salt-minion${id}.vmwarevm/ nogui
done

exit 0
