#!/bin/sh

ps ax | grep processing_queue_processor.php | grep -v grep | awk '{ print $1 }' | xargs -r kill -9
