#!/bin/bash

# quick and dirty upper to lowercase script
if [ -n "$1" ]; then
  echo $1 | tr [:upper:] [:lower:]
else
  echo "Needs an argument..."
fi

exit 0
