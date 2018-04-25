#!/usr/bin/php
<?php
/* basic flow:

loop through list of IP addresses
DNS check against 8.8.8.8
does it resolve to 216.115.94.115?
also get NS records

*/

// only display important errors
error_reporting(E_ERROR | E_WARNING | E_PARSE);

// command-line arguments
function parseArgs($argv){
    array_shift($argv);
    $out = array();
    foreach ($argv as $arg){
        if (substr($arg,0,2) == '--'){
            $eqPos = strpos($arg,'=');
            if ($eqPos === false){
                $key = substr($arg,2);
                $out[$key] = isset($out[$key]) ? $out[$key] : true;
            } else {
                $key = substr($arg,2,$eqPos-2);
                $out[$key] = substr($arg,$eqPos+1);
            }
        } else if (substr($arg,0,1) == '-'){
            if (substr($arg,2,1) == '='){
                $key = substr($arg,1,1);
                $out[$key] = substr($arg,3);
            } else {
                $chars = str_split(substr($arg,1));
                foreach ($chars as $char){
                    $key = $char;
                    $out[$key] = isset($out[$key]) ? $out[$key] : true;
                }
            }
        } else {
            $out[] = $arg;
        }
    }
    return $out;
}

// usage function
function usage() {
        global $argv;
        echo "Usage: {$argv[0]} -F=<full path to text file with domain names> -O=<csv> [ -D ]\n";
        echo " -D: Turn on debugging\n";
        exit(254);
}

// logging function -- used when debugging is turned on
function debugecho($domain, $msg) {
        $today = date("Y-m-d H:i:s");
        $debugFormat = "[ %19s ] >> %s >> %s\n";
        printf($debugFormat, $today, $domain, $msg);
}

// get cli arguments
$params = parseArgs($argv);
if(isset($params['F'])) {
        $domainFile = $params['F'];
} else {
        usage();
}

if(isset($params['O'])) {
        $outFile = $params['O'];
} else {
        usage();
}

// function for dig lookups
function Dig ($domain) {
    $dig = `dig @8.8.8.8 $domain ANY`;
    preg_match_all("/in\s+ns\s+(.+?)\s+/is",$dig,$name_servers,PREG_PATTERN_ORDER);
    preg_match_all("/$domain.\s+[0-9]+\s+in\s+a\s+([0-9.]+)\s+/is",$dig,$ips,PREG_PATTERN_ORDER);
    $dns[name_servers] = $name_servers[1];
    $dns[ips] = $ips[1];
    return($dns);
}

// can we write to the output file?
if (file_exists($outFile)) {
	echo "$outFile already exists -- will not overwrite.\n";
	die;
}
    
// can we write to the output file?
if (!file_put_contents($outFile, "TEST OUTPUT\n")) {
	echo "Unable to create output file $outFile.\n";
	die;
} else {
	unlink($outFile);
}

// counter
$x=1;

// load file into array
$loadFile = file($domainFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
if($loadFile) {
	// start CSV
	$csvOut = "domain,ip1,ip2,ip3,ip4,ns1,ns2,ns3,ns4,ns5\n";

	foreach($loadFile as $domain) {
		echo "$x: $domain\n";
		$x++;

		$result = Dig($domain);

		// csv record
		$csvOut .= "$domain,";

		// write ip addresses to csv
		if($result['ips']) {
			$ipCount=0;
			foreach($result['ips'] as $ip) {
				$csvOut .= "$ip,";
				$ipCount++;
				if($ipCount >= 4) {
					break;
				}
			}
			
			switch($ipCount) {
				case 1:
					$csvOut .= ",,,";
					break;
				case 2:
					$csvOut .= ",,";
					break;
				case 3:
					$csvOut .= ",";
					break;
			}
		} else {
			$csvOut .= ",,,,";
		}

		// write nameservers to csv
		if($result['name_servers']) {
			$nsCount=0;
			foreach($result['name_servers'] as $ns) {
				$csvOut .= "$ns,";
				$nsCount++;
				if($nsCount >= 5) {
					break;
				}
			}
		} else {
			$csvOut .= ",,,,,";
		}

		// csv newline
		$csvOut .= "\n";

		// output to file
		file_put_contents($outFile, $csvOut, FILE_APPEND | LOCK_EX);

		// mandatory sleep
		sleep(1);
	}
} else {
	echo "Couldn't load $domainFile. Exiting.\n";
}
?>
