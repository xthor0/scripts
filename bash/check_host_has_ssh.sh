#!/bin/bash

function nmap_check() {
  nmap -Pn -p 22 ${1} --open | grep -q open
  return $?
}

while true; do
  echo "Checking host ${1} for SSH..."
  nmap_check ${1}
  if [ $? -eq 0 ]; then
    msg="Host ${1} is alive!"
    echo ${msg}
    say ${msg}
    break
  fi
  echo "Host is not responding, sleeping..."
  sleep 10
done

