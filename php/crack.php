#!/usr/bin/php
<?php

$XOR = 0xC;
$decoded = "";
$encoded = "";
//$string = "mhze`";

// commented out -- this is the encryption method used to store in the database
/*
for ($i = 0; $i < strlen( $string ); $i++)
{
	$encoded .= chr( $XOR ^ ord( substr( $string, $i, 1) ) );
}
*/

// connect to the database, pull out all the users to array
$link = mysql_connect('db-pool.datamark.com', 'datamark', 'you*h5!');
if (!$link) {
    die('Could not connect: ' . mysql_error());
}
mysql_select_db('courseEval');
$result = mysql_query("SELECT username,password from user");

while ($row = mysql_fetch_array($result, MYSQL_ASSOC)) {
	// reverse the encryption -- woot
	$username = $row['username'];
	$passcrypt = $row['password'];
	$password = '';
	for ($i = 0; $i < strlen( $passcrypt ); $i++)
	{
		$password .= chr( ord( substr( $passcrypt, $i, 1) ) ^ $XOR );
	}

	printf("username: %-20s password: %s\n", $username, $password);
}

mysql_free_result($result);
mysql_close($link);


// reverse the encryption -- woot
for ($i = 0; $i < strlen( $encoded ); $i++)
{
	$decoded .= chr( ord( substr( $encoded, $i, 1) ) ^ $XOR );
}

/*
echo $encoded."\n";
echo $decoded."\n";
*/


?>
