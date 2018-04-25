#!/bin/sh

ps ax | grep trigger_deliverer.php | grep -v grep | awk '{ print $1 }' | xargs kill -9
