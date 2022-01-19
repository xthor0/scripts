#!/bin/bash

function discpresent() {
  echo
  tput sc
  while true; do
    file -s /dev/sr0 >& /dev/null
    if [ $? -eq 0 ]; then
      tput el
      echo "Disc loaded!"
      return
    else
      echo -n "Waiting for disc..."
      tput rc
      sleep 5
    fi
  done
}

function gettitle() {
  discinfo=$(mktemp -t makemkvcon-info.XXXX)
  echo "Finding disc title..."
  makemkvcon --progress=-stdout -r info dev:/dev/sr0 > ${discinfo}
  title=$(grep ^DRV:0 ${discinfo} | cut -d \, -f 6 | tr -d \")
  echo "Found disc title: ${title}"
  if [ ${#title} -le 1 ]; then
    echo "Valid title not found, skipping this disc"
    echo "last message logged by makemkv: "
    grep ^MSG ${discinfo} | tail -n1
    retval=1
  else
    export disctitle="${title}"
    retval=0
  fi
  rm ${discinfo}
  return ${retval}
}

function makedir() {
if test -d "${1}"; then
  echo "Directory ${1} already exists... skipping this disc."
  return 1
fi

mkdir "${1}"
if [ $? -eq 0 ]; then
  echo "Created directory: ${1}"
else
  echo "Error creating directory!"
  return 1
fi
}

function ripdisc() {
echo "Ripping with makemkvcon..."
log=$(mktemp -t makemkvcon.log.XXXX)
( makemkvcon --progress=-stdout -r --decrypt --directio=true mkv dev:/dev/sr0 all "${1}" >& ${log} ) &
bgpid=${!}

# give makemkv a minute to start
sleep 2

while [ -d /proc/${bgpid} ]; do
  task=$(grep ^PRGC ${log} | wc -l)
    job="$(grep ^PRGC ${log} | tail -n1 | cut -d , -f 3 | tr -d '"')"
    jobprog="$(grep ^PRGV ${log} | tail -n1 | cut -d \: -f 2 | cut -d \, -f 1)"
    alljobprog="$(grep ^PRGV ${log} | tail -n1 | cut -d \: -f 2 | cut -d \, -f 2)"
    totalprog="$(grep ^PRGV ${log} | tail -n1 | cut -d \: -f 2 | cut -d \, -f 3)"

    # we need to make sure jobprog/totalprog are digits - otherwise, bc bitches
    if [[ ${jobprog} =~ ${re} ]] ; then
        progperc=$(echo "scale=4;(${jobprog} / ${totalprog}) * 100" | bc | head -c-3)
        allprogperc=$(echo "scale=4;(${alljobprog} / ${totalprog}) * 100" | bc | head -c-3)
        tput sc
        #tput el
        #echo "Debugging: jobprog = ${jobprog} :: totalprog = ${totalprog} :: progperc = ${progperc}"
        tput el
        echo -n "Task #${task} :: ${job} :: ${progperc} % (total progress: ${allprogperc})"
        sleep .5
        tput rc
    else
        sleep 1
    fi
done

# wait for bg process to exit, I don't know if this will work
wait ${bgpid}
retval=$?

# write a newline, or we'll clobber the last status message
echo

if [ ${retval} -ne 0 ]; then
  echo "Error. Here's some logging."
  tail ${log} | grep ^MSG
fi

rm ${log}
return ${retval}
}

function fixdir() {
  # some of these discs are either mislabled, or dupes
  # won't know which until I copy the contents and look at it
  if test -d "${1}"; then
    echo "Title ${1} already exists, appending integer..."
    for int in {1..10}; do
      test -d "${1}-${int}"
      if [ $? -eq 1 ]; then
        export disctitle="${1}-${int}"
        return
      fi
    done
    # if we get here, we have a problem
    echo "Oops, I appended digits and ran out."
    return 1
  else
    echo "No dir fixing required"
  fi
}

function isdone() {
echo "MakeMKV is done."

eject cdrom

echo "press CTRL-C to cancel, or we'll start looking for the next disc..."
sleep 10
}

while true; do
  discpresent
  gettitle
  if [ $? -eq 0 ]; then
    makedir "${disctitle}"
    if [ $? -eq 0 ]; then
      echo "Ripping disc ${disctitle}..."
      ripdisc "${disctitle}"
    fi
  else
    echo "Can't get the title for this disc."
  fi
  isdone
  unset disctitle
done

# ha, we never get here
exit 0
