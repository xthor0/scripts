<?php
ini_set('date.timezone', 'America/Denver');

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

// CLI arguments
$params = parseArgs($argv);
if(isset($params['D'])) {
	$domain = $params['D'];
} else {
	echo "No domain passed on command-line.\n";
	die;
}



require_once('phpwhois-4.2.2/whois.main.php');
$whois = new Whois();
$whoislookup = $whois->Lookup($domain);

var_dump($whoislookup);

// special handling required for .edu and .co.uk domains, for whatever reason
if(preg_match("/(\.edu$|\.co\.uk$)/", $domain)) {
	foreach($whoislookup['rawdata'] as $line) {
		if(preg_match("/(domain expires|expiry date:)/i", $line)) {
			$rawdate = preg_split('/\:/', $line);
			var_dump($rawdate);
			$expiration = trim($rawdate[1]);
		}
	}
}

var_dump($expiration);
echo strtotime($expiration);
echo "\n";
echo strtotime("now");
echo "\n";
?>
