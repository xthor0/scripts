#!/bin/bash

total_wc=9236
total_sz="48G"
loopcount=0

while true; do
  cur_sz=$(du -hs ~/Music | awk '{ print $1 }')
  cur_wc=$(find ~/Music | wc -l)
  echo "$(date) :: Size: ${cur_sz}/${total_sz} :: Count: ${cur_wc}/${total_wc}"

  # are we done?
  if [ $cur_wc == $total_wc ]; then
    echo "Sync finished!"
    exit 100
  fi

  # otherwise, remind the idiot watching this that he can get out at any time...
  # I mean, I wrote this, why did I spend 5 minutes putting this logic in? :)
  let loopcount+=1
  if [ $loopcount == 10 ]; then
    loopcount=0
    echo "Press ctrl-c to stop..."
  fi
  sleep 30
done

exit 0
