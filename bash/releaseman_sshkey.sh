#!/bin/bash

. /usr/local/bin/servers

for server in $WEB_SERVERS $APP_SERVERS; do
	ssh $server "
		echo sudopass | sudo -S whoami >&/dev/null
		if [ \$? -eq 0 ]; then
			echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAqabZE5q6D91rr9s4spUdaUcCsgIVK9RjyA8X+CdaA7bD2nMDnR/Q9++Smd5dM8+Yr4tNw7wdsmmWZzdmv9YswtbgC8hX3gyVJlSpCZhkpjFZPB4KExepaGpw+Lv76CorDFi2X16GYYi0wBU0L/Q6M8dLiy6Ys8ZeWx9k9TbXGh+ISfhpB81dtSQmhlOBmSrIqESAHRh6s2Mnl1NCUuojFu2MPlAd08M0a4bzF4kSpsZrJ2pNA+KgbGRDhuNR+O1AHNsfWOu6thbFLrusKd62H2Aw87dCYJAY7RZ1icQENFXu8Q8kuDrJNuzjqYR/Os4pk4MU0Sg/MeyC2gIDCihxzw== releaseman@mesquite.datamark.com' | sudo tee /home/releaseman/.ssh/authorized_keys
		else
			echo "Error running sudo..."
		fi
	" # END
done

exit 0
