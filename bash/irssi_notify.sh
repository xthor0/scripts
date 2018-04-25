#!/bin/bash

tail -f $HOME/.irssi/fnotify | while read heading message; do
  growlnotify -s -t "${heading}" -m "${message}"
  #say "${heading} says, ${message}"
done
