#!/usr/bin/php
<?php

$tzofile = "/home/bbrown/tzo_domains.txt";
$webdocsfile = "/home/bbrown/tmp/domains/domain_output.txt";

$loadTZOFile = file($tzofile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
if(!$loadTZOFile) {
	echo "Could not load $tzofile.\n";
	die;
}

$loadWDFile = file($webdocsfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
if(!$loadWDFile) {
	echo "Could not load $webdocsfile.\n";
	die;
}

$result = array_diff($loadWDFile, $loadTZOFile);
print_r($result);

?>
