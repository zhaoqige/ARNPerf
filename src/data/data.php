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
$_f = 'demo.log';
$_t = 1;


if (key_exists('f', $_get)) $_f = $_get['f'];
if (key_exists('t', $_get)) $_t = $_get['t'];

$_env = array(
		'file' => $_f,
		'type' => $_t,
		'limit' => 1024
);

$app = new AppLog($_env);
$_result = $app->exec($type = 1);

// prepare OUTPUT
$_resultString = JSON::encode($_result);
echo $_resultString;

?>
