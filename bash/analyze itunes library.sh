#!/usr/bin/env bash

grep Location /Users/bbrown/Dropbox/iTunes/iTunes\ Library.xml \
| egrep -o '<string>.*</string>' | sed 's/\<string\>//g' | sed 's/\<\/string\>//g' | sed 's/\%20/ /g' | sed 's/\#38\;//g' \
| while read file; do
	printf "%b\n" "${file//%/\\x}"
done

exit 0
