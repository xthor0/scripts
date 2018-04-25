#!/usr/bin/php
<?php
// only display important errors
error_reporting(E_ERROR | E_PARSE);

// we need the phpwhois package for this script to work properly
require('phpwhois-4.2.2/whois.main.php');

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
	echo "Usage: {$argv[0]} -F=<domain list text file> [ -D ]\n";
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
	$path = $params['F'];
} else {
	usage();
}

$count=1;
$rec=0;
$outFile = "/home/bbrown/tmp/domains/unique_customer_domains.txt";
$loadFile = file($params['F'], FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

if($loadFile) {
	$whois = new Whois();
	$total = count($loadFile);
	printf("%-10s %-35s %-35s %-35s %-20s\n", "#", "Domain", "Base domain", "Owner", "Expires");
	echo "========================================================================================================================\n";
	foreach($loadFile as $domain) {
		// to track progress
		$progress = sprintf("%03d" , $count) . "/$total";

		// we need to get the base domain name -- not the subdomain here
		$subdomains = explode('.', $domain);
		if(max(array_keys($subdomains)) != 1) {
			$domaintld = end($subdomains);
			$domainsld = prev($subdomains);
			$basedomain = $domainsld.".".$domaintld;
			if($basedomain == "co.uk") {
				// false positive -- whoops!
				$lookup = $domain;
			} else {
				$lookup = $basedomain;
			}
		} else {
			$lookup = $domain;
		}
	
		// have we already pulled whois information for this domain? if so -- no need to check it again
		$checked=0;
		if(isset($ownerInfo)) {
			foreach($ownerInfo as $record) {
				if($record['domain'] == $lookup) {
					$checked=1;
					$owner = $record['owner'];
				}
			}
		}
		
		if($checked == 0) {
			// whois lookup
			$whoislookup = $whois->Lookup($lookup);
			$owner = $whoislookup['regrinfo']['owner']['name'];
			$expiration = $whoislookup['regrinfo']['domain']['expires'];
			
			// populate search array
			$ownerInfo[$rec] = array("domain" => $lookup, "owner" => $owner, "expires" => $expiration);

			// csv output
			$csvOutput = sprintf("%s,%s\n", $lookup, $owner);

			// write out to unique file
			file_put_contents($outFile, $csvOutput, FILE_APPEND | LOCK_EX);

			// increment counter
			$rec++;

			// set sleep counter
			$sleep=1;
		} else {
			$sleep=0;
		}

		// output
		printf("%-10s %-35s %-35s %-35s %-20s\n", $progress, $lookup, $domain, $owner, $expiration);

		// counter increment
		$count++;

		// sleep
		sleep($sleep);
	}
} else {
	echo "Sorry -- couldn't load ".$params['F']."\n";
	die;
}
