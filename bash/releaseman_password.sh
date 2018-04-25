#!/bin/bash

for server in qahollywood.datamark.com qaseville.datamark.com qadns.datamark.com qa2hollywood.datamark.com qa2seville.datamark.com qa2dns.datamark.com damascus.datamark.com caracas.datamark.com moscow.datamark.com sthollywood.datamark.com stseville.datamark.com seville101.datamark.ftp seville102.datamark.ftp seville201.datamark.ftp seville202.datamark.ftp hollywood101.datamark.ftp hollywood102.datamark.ftp hollywood103.datamark.ftp hollywood104.datamark.ftp hollywood105.datamark.ftp hollywood201.datamark.ftp hollywood202.datamark.ftp hollywood203.datamark.ftp hollywood204.datamark.ftp hollywood205.datamark.ftp hollywood206.datamark.ftp boston.datamark.com mesquite.datamark.com; do
	echo "$server:"
	ssh $server "
		echo sudopassword | sudo -S whoami >&/dev/null
		if [ \$? -eq 0 ]; then
			#echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA7eQbICMI/vDbJWY4izTVicrtdEl5tUVaB5kdeMEOIDeEY086BkgLBJz3J/eO5Wl3y82QDA6e/PB10ojLJaNBRUxH9/z6a/vPiBE74GdCxEp5RIyd6s4ges/raqI48RMhVjQYcMjG8mf/3Y5vzttr/MQkdDIxjx4n4BxoAbhmFjEqnNWPNPCKs1jmEh+6wXncCID63AZjzW9kPWDwuejqiTgw8zN1Mq6OPBFTF/nECtmJePiiB9Wnn3sCKKVUzhrJQXQnO9tN91cSYazhYnpM1PnSGkNG4QCkKeyQYStXMul7p3GoMj1s2/tG3+S5oxlFLJOiE09iVK3/JvfdTNddaw== releaseman@mesquite.datamark.com' | sudo tee /home/releaseman/.ssh/authorized_keys
			uid=\"\`id -u releaseman\`\"
			if [ -z \"\$uid\" ]; then
				echo \"Cannot determine releaseman UID -- error!\"
				exit 5
			fi

			if [ \$uid -eq 11430 ]; then
				echo \"\`hostname\` is using Winbind, password is set at domain controller.\"
			elif [ \$uid -eq 10003 ]; then
				echo \"\`hostname\` is using LDAP, password is set at domain controller.\"
			else
				echo pheK0ich | sudo passwd --stdin releaseman
			fi
		else
			echo \"Error running sudo...\"
		fi
	" # END
done

exit 0
