#!/usr/bin/php
<?php

// parse CLI arguments
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

// get cli arguments
$cliargs = parseArgs($argv);

// we need to have an ENV variable passed in
if(!isset($cliargs["env"])) {
	echo "You must pass in --env, stupid.\n";
	die;
}

// load contents of zone files and merge them into single array
$zonelist1 = file('/home/bbrown/qadns/'.$cliargs["env"].'/etc/bind/zones.lst', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$zonelist2 = file('/home/bbrown/qadns/'.$cliargs["env"].'/etc/bind/named.conf.local', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$zonelist = array_merge($zonelist1, $zonelist2);
$zonefilepath = '/home/bbrown/qadns/'.$cliargs["env"].'/var/named/';
$hostsfile = '/home/bbrown/qadns/'.$cliargs["env"].'/hosts.conf';
$whitelistfile = '/home/bbrown/qadns/'.$cliargs["env"].'/whitelist.conf';
$recordcount = 0;
$duperecordcount = 0;
$zonecount = 0;

// process zone lists
if($zonelist) {
	foreach($zonelist as $linenum => $line) {
		//echo $linenum . " => " . $line . "\n";
		if(preg_match('/^zone .* {/', $line)) {
			$domainsplit = preg_split('/ /', $line);
			$domain = $domainsplit[1];
			for($i=$linenum+2; $i<=$linenum+7; $i++) {
				if(isset($zonelist[$i])) {
					if(preg_match('/ *file ".*/', $zonelist[$i])) {
						$zonefilestring = trim($zonelist[$i]);
						$filesplit = preg_split('/ /', $zonefilestring);
						$zonefile = $filesplit[1];
					}
					if(preg_match('/^};/', $zonelist[$i])) {
						break;
					}
				}
			}
			// remove bad characters from output
			$domain = preg_filter('/[";]/', '', $domain);
			$zonefile = preg_filter('/[";]/', '', $zonefile);

			// insert into the array
			//$output[] = $domain;

			// debug
			//echo "====== Domain " . $domain . " ======\n==> Zone file: " . $zonefile . "\n";

			// parse the zone file for relevant data
			if($zonefilepath . $zonefile) {
				$loadzone = file($zonefilepath . $zonefile);
				foreach($loadzone as $zfln => $ln) {
					// strip whitespace from $ln
					$ln = preg_replace('/\s+/', ' ', $ln);

					// debug
					if(preg_match('/.* (A|CNAME) .*/', $ln)) {
						// increment record count
						$recordcount++;

						// parse the record into an array for easier parsing
						$base = preg_split('/ /', $ln);

						$host = $base[0];
						$recordtype = $base[1];
						$ip = $base[2];

						// skip ns-auth records, we don't want them
						if(preg_match('/ns-auth/', $host)) {
							continue;
						}

						// translate @ or * records to $domain
						if(preg_match('/(@|\*)/', $host)) {
							$host = $domain;
						} else {
							$host = $host.".".$domain;
						}
						
						// process the record type accordingly
						switch ($recordtype) {
							case ($recordtype == "CNAME"):
								$match = 0;
								if(isset($hosts[$domain])) {
									// if this is a CNAME, $ip should be a short hostname, not an IP address
									// we have to find the IP this CNAME should be pointed at and set it accordingly
									$search = "/address=\/".$ip.".".$domain."\/.*/";
									foreach($hosts[$domain] as $record) {
										if(preg_match($search, $record)) {
											$match = preg_split('/\//', $record);
											$ip = $match[2];
											$hosts[$domain][] = "address=/".$host."/".$ip;
										}
									}
								}
								if($match == 0) {
									echo "Can't find matching A record for CNAME: $ip.$domain\n";
								}
								break;
							case ($recordtype == "A"):
								// if IP starts with 10.50, we create a DNSMasq address entry for this record
								if(preg_match('/10\.5(0|1)/', $ip)) {
									// dedupe -- go through all previous records for this domain, see if we already have a base
									// domain wildcard pointed to the same IP. If we do, this record is not needed.
									$match = 0;
									if(isset($hosts[$domain])) {
										$search = "/address=\/".$domain."\/".$ip."/";
										foreach($hosts[$domain] as $record) {
											if(preg_match($search, $record)) {
												$match = 1;
											}
										}
									}

									if($match == 0) {
										$hosts[$domain][] = "address=/" . $host . "/" . $ip;
									}
								} else {
									$whitelist[$domain][] = "server=/" . $host . "/" . "10.0.0.14";
									$whitelist[$domain][] = "server=/" . $host . "/" . "10.0.0.16";
								}
								break;
						}

						// commented again... d'oh
						if(isset($yousuckrocks)) {
						// check IP address -- if it starts with 10.50.0, we add an address entry
						// if it starts with something else, it's a whitelisted domain
						if(preg_match('/10\.50\.0/', $ip)) {
							$recordcount++;
							// skip records that begin with ns-auth
							if(!preg_match('/^ns-auth.datamark.com/', $basedomain)) {
								// @ gets translated to just $domain
								if(preg_match('/^(@|*)/', $basedomain)) {
									$hosts[$domain][] = "address=/" . $domain . "/" . $ip;
								} else {
									$subdomainrecord = "address=/".$basedomain.".".$domain."/".$ip;
									// we need to check $hosts[$domain] and see if we already
									// have a $domain entry with the same IP
									if(isset($hosts[$domain])) {
										if(in_array("address=/".$domain."/".$ip, $hosts[$domain])) {
											$duperecord = 1;
										}
									}

									if(isset($duperecord)) {
										unset($duperecord);
									} else {
										$hosts[$domain][] = "address=/" . $basedomain . "." . $domain . "/" . $ip;
									}
								}
							}
						} else {
							if(!preg_match('/^ns-auth.datamark.com/', $basedomain)) {
								$recordcount++;
								if(preg_match('/^@/', $basedomain)) {
									$whitelist[$domain][] = "server=/" . $domain . "/" . "10.0.0.14";
									$whitelist[$domain][] = "server=/" . $domain . "/" . "10.0.0.16";
								} elseif(preg_match('/^\*/', $basedomain)) {
									$whitelist[$domain][] = "server=/" . "." . $domain . "/" . "10.0.0.14";
									$whitelist[$domain][] = "server=/" . "." . $domain . "/" . "10.0.0.16";
								} else {
									$whitelist[$domain][] = "server=/" . $basedomain . "." . $domain . "/" . "10.0.0.14";
									$whitelist[$domain][] = "server=/" . $basedomain . "." . $domain . "/" . "10.0.0.16";
								}
							}
						}
						} // end comment for debugging
					}
				}
			}
			
			//echo "=========END DOMAIN==========\n";
			$zonecount++;
		}
	}
	
	// print out statistics 
	echo "Zones found: " . $zonecount . "\n";
	echo "Records processed: " . $recordcount . "\n";

	// output to files
	if(isset($hosts)) {
		$whostsfile = fopen($hostsfile, 'w+');
		if($whostsfile) {
			fwrite($whostsfile, "#==========[ Host records ]==========\n");
			foreach($hosts as $domain => $record) {
				fwrite($whostsfile, "#======[ " . $domain . " ]======\n");
				foreach($record as $rec) {
					fwrite($whostsfile, "$rec\n");
				}
				fwrite($whostsfile, "\n");
			}
			fclose($whostsfile);
			echo "Hosts successfully written to " . $hostsfile . "\n";
		} else {
			echo "ERROR: Unable to open " . $hostsfile . "\n";
		}
	}

	if(isset($whitelist)) {
		$wwhitelist = fopen($whitelistfile, "w+");
		if($wwhitelist) {
			fwrite($wwhitelist, "#==========[ Whitelist records ]==========\n");
			foreach($whitelist as $domain => $record) {
				fwrite($wwhitelist, "#======[ " . $domain . " ]======\n");
				foreach($record as $rec) {
					fwrite($wwhitelist, "$rec\n");
				}
				fwrite($wwhitelist, "\n");
			}
			fclose($wwhitelist);
			echo "Whitelist records successfully written to " . $whitelistfile . "\n";
		} else {
			echo "ERROR: Unable to open " . $whitelistfile . "\n";
		}
	}
} else {
	echo "Could not load " . $zonelist . "!";
}


?>
