<?php
if (strpos($_SERVER['REQUEST_URI'],'meta-data') !== false) {
	$uriExplode = explode('/', $_SERVER['REQUEST_URI']);
	$vmname = $uriExplode[1];
	if($vmname == "meta-data") {
		$vmname = substr(str_shuffle(MD5(microtime())), 0, 10);
		echo "# no hostname specified in URI, generating random hostname\n";
	}
	echo 'instance-id: 1
local-hostname: ' . htmlspecialchars($vmname);
} elseif(strpos($_SERVER['REQUEST_URI'],'user-data') !== false) {
	echo '#cloud-config
users:
    - name: root
      passwd: toor
      ssh_authorized_keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
    - name: xthor
      shell: /bin/bash
      passwd: $y$j9T$0w359S20fRJmA2AD3zXUz0$Z6Y2d/6/KzdBSYm74mGtkv/ju6cYRNnIVitOL/7JwpB
      lock_passwd: false
      sudo: ALL=(ALL) NOPASSWD:ALL
      ssh_authorized_keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSUppn5b2njEQSw8FHqyZ0OZiPD14wEejulwnQ7gxLdQYJEqXMleHx4u/9ff3/jDXoGaBFiT2LmUTnpMV8HSj4jsB4PCoFAbq4XnlnwyBx7va/8LQOMdKsjF5W6peO+DYKh+ow9YaJvctzGPebkkNvhI0YFhZod58uoO7lyTnQXkMm8DXl6q7WhNfsZZiwr7tXicUZojU0msMiDpX1JvhGow+mKym0U/6cMgozypYfNbQ2PVkfNnadslp29O5Mfd5X4U+cbACa1sUYYqOT2Zz8C4t5QFXRY1LNokmRbcqbO01bygbE4S2TDnvRz+XZmfZTuw9MMgp7JPfo6cOfDYKf xthor
timezone: America/Denver
package_upgrade: true
runcmd:
    - touch /etc/cloud/cloud-init.disabled
' ;
} elseif (strpos($_SERVER['REQUEST_URI'],'vendor-data') !== false) {
	echo '#vendor-data intentionally left empty';
} else {
	echo '
	<html><head>
		<title>Metadata Server</title>
		<h1>Metadata server</h1>
		<p>you didn\'t say the magic word.</p>
	</html></head>
	';
}
?>
