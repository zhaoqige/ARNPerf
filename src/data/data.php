<?php
// Handle ajax request from "bing.html?f={$filename}"
// 6Harmonics Qige @ 2016.12.22
define('TASKLET_ID', 'DATA');

'use strict';
require_once 'base.filter.php';
require_once 'data.json.php';
require_once 'app.log.php';

// saved result
$_result = array();

// read user input
$_get = Filter::secureArray($_GET);
$_env = array(
		'file' => $_get['f'],
		'type' => $_get['t'],
		'limit' => 1024
);

$app = new AppLog($_env);
$_result = $app->exec($type = 1);

// prepare OUTPUT
$_resultString = JSON::encode($_result);
echo $_resultString;

?>
