#!/usr/bin/php
<?php
// only display important errors
error_reporting(E_ERROR | E_WARNING | E_PARSE);

// require DNS2
require_once 'Net/DNS2.php';

/*
What are we doing here? This is as much for my benefit as whoever else might use this code (because I forget stuff).

- loop through domain_output.txt
- find out type (CNAME or A record) and status (pointed at us or not) based on that record
- if A record, get authoritative name servers
- finally, compare to Matts.list.txt, which is an export from Godaddy, to see if it's ours, and make a note accordinly
*/

// counter
$count=1;

// csv output file
$outFile = "/home/bbrown/tmp/domains/vhost_dns_check.csv";

// load datamark-owned domain list into array
$DMDomains = file("/home/bbrown/tmp/domains/Matts.list.txt", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

// load vhost domains
$loadFile = file("/home/bbrown/tmp/domains/all_vhosts.txt", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

// get total number of records to show progress
$total = count($loadFile);

// output to screen for progress
printf("%-10s %-35s %-7s %-10s %-30s %-25s %-25s %-5s\n", "#", "Domain", "Type", "Status", "Answer", "NS1", "NS2", "Owned by DM");
echo "=================================================================================================================================================================\n";

// csv output for later parsing
$csvOutput = sprintf("%s,%s,%s,%s,%s,%s,%s\n", "Domain", "Type", "Status", "Answer", "NS1", "NS2", "OwnedByDM");
file_put_contents($outFile, $csvOutput, LOCK_EX);

// loop through domains
foreach($loadFile as $domain) {
	// build progress variable
	$progress = sprintf("%04d" , $count) . "/$total";

	// create new resolver object, passing in an array of name
	// servers to use for lookups
	$r = new Net_DNS2_Resolver(array('nameservers' => array('8.8.8.8', '8.8.4.4')));

	// execute the query request
	$failed=0;
	try {
		$result = $r->query($domain, 'ANY');
	} catch(Net_DNS2_Exception $e) {
		//echo "::query() failed: ", $e->getMessage(), "\n";
		//$results[$count] = array("domain" => $domain, "status" => "failed");
		$status = "CRITICAL";
		$answer = "FAILED";
		$failed=1;
	}

	if($failed == 0) {
		// loop through the answer, printing out the MX servers retured.
		foreach($result->answer as $record) {
			// is this a CNAME?
			if(isset($record->cname)) {
				$type = "CNAME";
				$answer = $record->cname;
				if($record->cname == "web.dmfailover.com") {
					$status = "OK";
				} else {
					$status = "CRITICAL";
				}
			} else {
				// not a CNAME -- what about an A record?
				if(isset($record->address)) {
					$type = "A";
					$answer = $record->address;
					if($answer == "216.115.94.115") {
						$status = "OK";
					} else {
						$status = "CRITICAL";
					}

					// we need to get the base domain name -- not the subdomain here
					$subdomains = explode('.', $domain);
					if(max(array_keys($subdomains)) != 1) {
						$domaintld = end($subdomains);
						$domainsld = prev($subdomains);
						$basedomain = $domainsld.".".$domaintld;
						if($basedomain == "co.uk") {
							// false positive -- whoops!
							$basedomain = $domain;
						}
					} else {
						$basedomain = $domain;
					}
										

					// execute the query request
					$nsfailed=0;
					try {
						$nsresult = $r->query($basedomain, 'NS');
					} catch(Net_DNS2_Exception $q) {
						$nsfailed=1;
					}

					if($nsfailed == 0) {
						$nsCount=1;
						foreach($nsresult->answer as $nsrecord) {
							if($nsCount == 1) {
								$ns1 = $nsrecord->nsdname;
							} elseif($nsCount == 2) {
								$ns2 = $nsrecord->nsdname;
							} else {
								break;
							}
							$nsCount++;
						}
					} else {
						$ns1 = "FAILED";
						$ns2 = "FAILED";
					}
				}
			}

		}

		/*
		// look for $domain in $DMDomains (the list of DM-owned domain names)
		$cOwned = in_array($domain, $DMDomains);
		if($cOwned) {
			$owned = "YES";
		} else {
			$owned = "NO";
		}
		*/
		$owned = "CUST";
		foreach($DMDomains as $oDomain) {
			if(preg_match("/$oDomain/", $domain)) $owned = "DM";
		}


	}

	// print out results
	printf("%-10s %-35s %-7s %-10s %-30s %-25s %-25s %-5s\n", $progress, $domain, $type, $status, $answer, $ns1, $ns2, $owned);

	// csv output
	$csvOutput = sprintf("%s,%s,%s,%s,%s,%s,%s\n", $domain, $type, $status, $answer, $ns1, $ns2, $owned);
	file_put_contents($outFile, $csvOutput, FILE_APPEND | LOCK_EX);

	// unset the variables for the next go-round
	unset($domain);
	unset($type);
	unset($status);
	unset($answer);
	unset($ns1);
	unset($ns2);
	unset($owned);

	// increment counter
	$count++;

	// sleep
	sleep(1);

	/*
	// debug early exit
	if($count == 10) {
		echo $csvOutput;
		die;
	}
	*/
}

?>
