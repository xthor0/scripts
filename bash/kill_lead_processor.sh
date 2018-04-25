#!/bin/sh

ps ax | grep lead_processor.php | grep -v grep | awk '{ print $1 }' | xargs -r kill -9
