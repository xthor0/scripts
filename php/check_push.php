#!/usr/bin/php
<?php

//$domainList = file('/home/bbrown/vhosts/activeVhosts.txt');
$domainList = array(
	"californiaculinary4me.com",
	"waldenbaltimore.com"
);
$serverList = file('/usr/local/bin/servers');
$output = "%-5d %-40s %-30s %-10s %-10s\n";
$fileOutput = "%d,%s,%s,%s,%s\n";
$primaryServer = "hollywood.datamark.com";
$logfile = '/home/bbrown/vhosts/output.log';
$outputFile = '/home/bbrown/vhosts/activeVhosts.csv';

// begin
ini_set('error_log',$logfile);

// output file checks
if(is_file($outputFile)) {
	if(is_writable($outputFile)) {
		$outFile = fopen($outputFile, 'w');
		if($outFile) {
			fwrite($outFile, sprintf($fileOutput, "Num", "Domain", "Server", "Active?", "Match?"));
		} else {
			die("1: Cannot open ".$outputFile." for writing!\n");
		}
	} else {
		die("2: Cannot open ".$outputFile." for writing!\n");
	}
} else {
	if(is_dir(dirname($outputFile))) {
		if(is_writable(dirname($outputFile))) {
			$outFile = fopen($outputFile, 'w');
			if($outFile) {
				fwrite($outFile, sprintf($output, "Num", "Domain", "Server", "Active?", "Match?"));
			} else {
				die("3: Cannot open ".$outputFile." for writing!\n");
			}
		} else {
			die("4: Cannot open ".$outputFile." for writing!\n");
		}
	} else {
		die("5: Cannot open ".$outputFile." for writing!\n");
	}
}

// parse serverList and find $WEB_SERVERS, and turn that into a useable PHP array
foreach($serverList as $line) {
	if(preg_match("/(WEB_SERVERS)/", $line)) {
		$string = preg_split('/=/', $line);
		$webServers = preg_replace('/"/', '', $string[1]);
		$webServers = explode(" ", $webServers);
	}
}

// function to retrieve URI from a specific server
function fetchURI($server, $domain) {
	$match = '/^(Date|Set-Cookie|Expires|x-node|Server):.*/';
	$socket = fsockopen($server, 80, $errno, $errstr, 30);
	if($socket) {
		$output = "GET / HTTP/1.1\r\n";
		$output .= "host: www.waldenonlineeducation.com\r\n";
		$output .= "Connection: Close\r\n\r\n";
		fwrite($socket, $output);
		while(!feof($socket)) {
			$result = fgets($socket, 128);
			// remove headers that can skew the hash
			if(!preg_match($match, $result)) {
				$input[] = $result;
			}
		}
		fclose($socket);
		
		// convert input var to string
		$input = implode('', $input);

		// return this as output
		$return[0] = sha1($input);
		$return[1] = $input;
		//error_log("Server: ".$server." Domain: ".$domain." hash: ".$return[0]." Index: ".$input);
		error_log("Server: ".$server." Domain: ".$domain." hash: ".$return[0]);
	} else {
		$return = 0;
		error_log("Server: ".$server." Domain: ".$domain." Could not open connection.");
	}
	return $return;
}

// header line for terminal output
printf($output, "#", "Domain", "Server", "Active?", "Match?");

$num = 0;
foreach($domainList as $domainname) {
	// counter
	$num++;
	$domainname = trim($domainname);

	// get the content of this site from the primary server
	$primarySite = fetchURI($primaryServer, $domainname);
	foreach($webServers as $server) {
		$server = trim($server);
		if($server == $primaryServer) {
			continue;
		} else {
			// is this pointed at Datamark? -- check DNS first
			$hostIP = trim(shell_exec("dig @8.8.8.8 +short ".$domainname));
			$match = "/(66\.133\.120\.242|206\.173\.159\.200|66\.133\.118\.219|65\.44\.112\.62)/";
			if(preg_match($match, $hostIP)) {
				// load site
				$sunsetTitle = "/(\<title\>Site or Page Not Available\!\<\/title\>|\<title\>phpinfo\(\)\<\/title\>)/i";
				$remoteSite = fetchURI($server, $domainname);
				if($remoteSite == "0") {
					$active = 0;
					if($remoteSite == $primarySite) {
						$match = 1;
					} else {
						$match = 0;
					}
				} else {
					// check for sunset
					if(preg_match($sunsetTitle, $remoteSite[1])) {
						$active = 0;
					} else {
						$active = 1;
					}

					// match against primary
					if($remoteSite[0] == $primarySite[0]) {
						$match = 1;
					} else {
						$match = 0;
					}
				}
			} else {
				$match = "N/A";
				$active = 0;
			}
			printf($output, $num, $domainname, $server, $active, $match);
			fwrite($outFile, sprintf($fileOutput, $num, $domainname, $server, $active, $match));
		}
	}
	/*
	// stop after 10 domains
	if($num == 5) {
		die("Time to stop!\n");
	}
	*/
}
?>
