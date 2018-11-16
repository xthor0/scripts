#!/bin/bash

# this script expects the minions to be named correctly, and the snap to be named Clean

for id in 1 2 3; do
  echo "Reverting salt-minion${id} to snapshot, please wait..."
  vmrun stop ~/Documents/Virtual\ Machines.localized/salt-minion${id}.vmwarevm/ hard
  vmrun revertToSnapshot ~/Documents/Virtual\ Machines.localized/salt-minion${id}.vmwarevm/ Clean
  vmrun start ~/Documents/Virtual\ Machines.localized/salt-minion${id}.vmwarevm/ nogui
  echo "===>"
done

exit 0
