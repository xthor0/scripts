#!/bin/sh

echo "Starting VNC tunnel to home.xthorsworld.com on localhost:5900..."
echo "press ctrl-c to exit..."
ssh -C -N home.xthorsworld.com -L 5900:127.0.0.1:5900

exit $?
