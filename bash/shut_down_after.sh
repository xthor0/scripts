#!/bin/bash

# Default duration variable
DURATION=""

# Parse arguments using getopts
while getopts "m:" opt; do
  case $opt in
    m) DURATION=$OPTARG ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Check if duration was provided
if [[ -z "$DURATION" ]]; then
    echo "Error: Please specify minutes using -m"
    echo "Usage: $0 -m <minutes>"
    exit 1
fi

echo "Starting countdown. System will shutdown in $DURATION minutes."

# Countdown loop
while [ $DURATION -gt 0 ]; do
	echo "$(date) :: Shutdown command will be issued in: $DURATION minutes"
    sleep 60
    ((DURATION--))
done

echo "Time is up. Shutting down..."
sudo shutdown -h now
