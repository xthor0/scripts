#!/bin/bash

ssh -C -N home.xthorsworld.com -L 3389:10.200.99.204:3389
echo "Tunnel is running -- press CTRL-C to terminate."

exit 0
