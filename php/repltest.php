#!/usr/bin/php
<?php
function db_conn() {
	// database variables
	$dbHost = '10.2.1.230';
	$dbUser = 'repltest';
	$dbPass = 'r3plt35t!';
	$dbSel = 'repltest';

	$dbConn = mysql_connect($dbHost, $dbUser, $dbPass);
	if($dbConn) {
		printf("Debug: Connected to " . $dbHost . "\n");
		mysql_select_db($dbSel, $dbConn);
	} else {
		printf("Debug: Error connecting to " . $dbHost . "\n");
	}

	// return connection value
	return $dbConn;
}

function db_close($dbConn) {
	mysql_close($dbConn);
}

// connect to database
$dbConn = db_conn();

// count rows in repltest.test table
$sql = 'SELECT count(field1) FROM test';
$result = mysql_query($sql);
$rows = mysql_result($result, 0);
echo $rows . " record(s) found in repltest.test table.\n\n";

// insert a bunch of crap into the database and time it
$mtime = microtime(); 
$mtime = explode(" ",$mtime); 
$mtime = $mtime[1] + $mtime[0]; 
$starttime = round($mtime, 4); 

for($i=1;$i<=1000;$i++) {
	$string1 = base_convert(mt_rand(0x1D39D3E06400000, 0x41C21CB8E0FFFFFF), 10, 36);
	$string2 = base_convert(mt_rand(0x1D39D3E06400000, 0x41C21CB8E0FFFFFF), 10, 36);
	$sql = "INSERT INTO test (field1,field2) VALUES ('" . $string1 . "','" . $string2 . "')";
	$result = mysql_query($sql);
	echo ".";
}

$mtime = microtime(); 
$mtime = explode(" ",$mtime); 
$mtime = $mtime[1] + $mtime[0]; 
$endtime = round($mtime, 4); 
$totaltime = ($endtime - $starttime);
$totaltime = round($totaltime, 4);

echo "\n1000 rows inserted in ".$totaltime." seconds.\n";

// disconnect from database
db_close($dbConn);

?>
