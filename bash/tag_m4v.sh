#!/bin/bash


for i in *.m4v; do
  title=$(echo $i | cut -c 31- | sed 's/\.m4v//g')
  episode=$(echo $i | cut -b 26-27)
  season=$(echo $i | cut -b 23-24)
  echo $i
  echo "Title: $title :: Episode: $episode :: Season: $season"
  AtomicParsley "${i}" --title "The Big Bang Theory - Season ${season}, Episode ${episode} - ${title}" --overWrite
done

exit 0
