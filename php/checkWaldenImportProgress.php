#!/usr/bin/php
<?php
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
	echo "Usage: {$argv[0]} -P=<path to Walden temp files>\n";
	exit(254);
}

// function used to properly format output to screen
function vecho($completed,$total,$processed,$avg,$rps) {
	// based on this bash output
	// printf "[%s %s] %8d / %8d / %3d / %3d / %3d\n" $date $time $completed $records $completeddiff $average $rps
	$today = date("Y-m-d H:i:s");
	$debugFormat = "[ %19s ] >> %8d / %8d / %3d / %3d /%3d\n";
	printf($debugFormat, $today, $completed, $records, $completedDiff, $avg, $rps);
}

// get cli arguments
$params = parseArgs($argv);
if(isset($params['P'])) {
	$path = $params['P'];
} else {
	usage();
}

// make sure path is valid
if(!is_dir($path)) {
	echo "Invalid directory specified: $path\n";
	exit(255);
}

// open all files in directory
if ($handle = opendir($path)) {
	while (false !== ($file = readdir($handle))) {
		if ($file != "." && $file != "..") {
			$fullPath = $path."/".$file;
			if(is_file($fullPath)) {
				$lines = count(file($fullPath));

				if($loadFile) {
					// increment counter
					$i++;


?>