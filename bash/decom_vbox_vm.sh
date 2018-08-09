#!/bin/bash

# decom all VMs that start with whatever you specify
# get command-line args
while getopts "n:f" OPTION; do
  case $OPTION in
    n) vmname="$OPTARG";;
    f) force="YES";;
    *) usage;;
  esac
done

# make sure an argument was passed
if [ -z "${vmname}" ]; then
  echo "You must specify a string to search the VM name for with the -n option."
  exit 255
fi

# get a list of VMs that will be affected
vmlist=$(vboxmanage list vms | grep ${vmname} | cut -d \" -f 2)

# print it out and tell the end user
if [ ${#vmlist} -eq 0 ]; then
  echo "There are no virtual machines with names that match the string ${vmname}. Exiting."
  exit 0
else
  echo "The following virtual machines will be shut down and deleted: "
  vboxmanage list vms | grep ${vmname} | cut -d \" -f 2
  echo
  if [ -n "${force}" ]; then
    echo "Force option passed, not asking any questions..."
    nukeme="YES"
  else
    echo "Type YES (in all caps) and press ENTER to continue. Any other value exits the script."
    read -p ":> " proceed
    if [ "${proceed}" == "YES" ]; then
      nukeme="YES"
    else
      echo "Aborting. No actions taken."
      exit 255
    fi
  fi
fi

if [ -n "${nukeme}" ]; then
  vboxmanage list runningvms | grep ${vmname} | cut -d \" -f 2 | while read vm; do
    echo "Powering off ${vm} :: "
    vboxmanage controlvm ${vm} poweroff
  done
  vboxmanage list vms | grep ${vmname} | cut -d \" -f 2 | while read vm; do
    echo "Deleting ${vm} :: "
    vboxmanage unregistervm ${vm} --delete
  done
fi

echo "Script completed."

exit 0
