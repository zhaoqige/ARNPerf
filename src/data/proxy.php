<?php
// Save upload files, then redirect to "bing.html?f={$filename}"
// 6Harmonics Qige @ 2016.12.22
define('TASKLET_ID', 'PROXY');

'use strict';
require_once 'base.filter.php';
require_once 'base.random.php';
require_once 'base.fileupload.php';
require_once 'base.html.php';


// saved result
$_result = array();

// app define
$_target = '../bing.html?f=';
$_fileId = 'log-file';

// server define
$_filepath = './log/';
$_filename = date('Ymd').'_'.AppRandom::str().'.log';
$_file = new AppFileUpload(Filter::secureArray($_FILES), $_fileId);


// save file, save result to $_result
// if succeded, then redirect
// if failed, then show error for 5 seconds, and go back
// start GOTO
for(;;) {
	// verify type
	if (!$_file) {
		$_result['err'] = 'bad file object';
		break;
	}
	
	$r = $_file->validFileType('log');
	if ($r) {
		$_result['err'] = 'invalid file type: '.$r;
		break;
	}
	
	// save .log file
	$r = $_file->saveToFile($_filename, $_filepath);
	if ($r) {
		$_result['err'] = 'filed to save file: '.$r;
		break;
	}
	
	// end GOTO
	break;
}

// clean up
unset($_file);


// prepare OUTPUT
if (key_exists('err', $_result)) {
	echo AppHtml::plainText($_result['err'], $_target, 5);
	//echo AppHtml::plainText($_result['err'], $_target, -1);
} else {
	// redirect
	echo AppHtml::redirectTo($_target.$_filename, 0);
	//echo AppHtml::redirectTo($_target, -1);
}

?>
