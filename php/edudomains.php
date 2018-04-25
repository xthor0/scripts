#!/usr/bin/php
<?php
// only display important errors
error_reporting(E_ERROR | E_WARNING | E_PARSE);

// require DNS2
require_once 'Net/DNS2.php';

$count=0;
$loadFile = file("/home/bbrown/tmp/domains/tzo_domains.txt", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
printf("Domain %-33s Type %-5s Status %-7s Answer %s\n", "", "", "", "");
echo "==============================================================================================================\n";
foreach($loadFile as $domain) {
	// create new resolver object, passing in an array of name
	// servers to use for lookups
	$r = new Net_DNS2_Resolver(array('nameservers' => array('8.8.8.8', '8.8.4.4')));

	// execute the query request
	$failed=0;
	try {
		$result = $r->query($domain, 'ANY');
	} catch(Net_DNS2_Exception $e) {
		//echo "::query() failed: ", $e->getMessage(), "\n";
		$results[$count] = array("domain" => $domain, "status" => "failed");
		$status = "dns lookup failed";
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
				}
			}

			/*
			we need to do one more thing...
			see if $domain is in the list of domain names we own
			you need the text file from Trevor first, though
			*/
		}

		// populate array
		$results[$count] = array("domain" => $domain, "type" => $type, "status" => $status, "answer" => $answer);
	}

	// print out results
	printf("%-40s %-10s %-14s %-34s\n", $domain, $type, $status, $answer);

	// unset the variables for the next go-round
	unset($domain);
	unset($type);
	unset($status);
	unset($answer);

	// increment counter
	$count++;

	// sleep
	sleep(1);
}

?>
