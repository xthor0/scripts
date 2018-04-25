#!/usr/bin/php
<?php
// recipient MUST be specified on the command-line...
if(isset($argv[1])) {
	$to = $argv[1];
} else {
	echo "Missing recipient on command-line.\n";
	exit;
}

// get hostname
$hostname = php_uname('n');

// contents of the email
$body = "This is a test email from the Nagios system. If your device is configured correctly, it should make a really annoying noise.

Sincerely,

Nagios
";

// send an email
$subject = 'Nagios Alert Test';
$headers = 'From: nagios@' . $hostname . "\r\n" .
    'X-Mailer: PHP/' . phpversion();

$email = mail($to, $subject, $body, $headers);
if($email) {
	exit(0);
} else {
	echo "Unable to send email...\n";
	printf($body);
	exit(255);
}

?>
