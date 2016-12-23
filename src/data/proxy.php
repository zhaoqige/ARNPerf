<?php
// use Proxy as alias of FileUpload
// Save upload files, then redirect to "bing.html?f={$filename}"
// 6Harmonics Qige @ 2016.12.23
define('TASKLET_ID', 'PROXY');

'use strict';
require_once 'base.filter.php';
require_once 'base.html.php';
require_once 'app.proxy.php';


// saved result
$_get = Filter::secureArray($_GET);
$_files = Filter::secureArray($_FILES);

// save file
$app = new AppProxy($_get, $_files);
$_result = $app->exec();

// prepare OUTPUT
if (key_exists('err', $_result)) {
	echo AppHtml::plainText($_result['err'], $_result['target'], 5);
	//echo AppHtml::plainText($_result['err'], $_result['target'], -1); // debug use only
} else {
	// redirect
	echo AppHtml::redirectTo($_result['target'], 0);
	//echo AppHtml::redirectTo($_result['target'], -1); // debug use only
}

?>
