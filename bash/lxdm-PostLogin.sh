#!/usr/bin/sh
#
# this should be placed in /etc/lxdm/PostLogin, otherwise fonts are effing huge on a 15" 4k display :)
# 
# if all we have connected is a single display - we need to up the DPI
if [ $(xrandr -q | grep -w connected | wc -l) -eq 1 ]; then
	echo 'Xft.dpi: 144' | xrdb -override
fi
