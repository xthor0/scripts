#!/bin/bash
SCHEMA="com.canonical.Unity.Panel"
OBJECT="systray-whitelist"
APP="$1"
if [ -z "$APP" ]; then
	echo "Please pass an argument to this script, i.e."
	echo "`basename $0` JungleDisk"
	exit 255
fi

if [ ! "$(gsettings get $SCHEMA $OBJECT 2>/dev/null || echo FALSE)" = "FALSE" ]; then
  echo "Whitelisting $APP to work around flawed distribution design.."
  OBJARRAY=$(gsettings get $SCHEMA $OBJECT | sed -s -e "s#\['##g" -e "s#', '# #g" -e "s#'\]##g")
  if [[ "${OBJARRAY[@]}" =~ "$APP" ]]; then
    echo "$APP already whitelisted, skipping"
  else
    OBJARRAY=("${OBJARRAY[@]}" $APP)
    OBJARRAY=$(echo ${OBJARRAY[@]} | sed -s -e "s# #', '#g")
    OBJSET="['"$OBJARRAY"']"
    gsettings set $SCHEMA $OBJECT "$OBJSET"
  fi
else
  echo "This is not a Canonical \"designed\" product."
fi
