<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';
require_once 'limit.app.php';
require_once 'base.random.php';
require_once 'base.fileupload.php';

/**
 * App File upload
 *
 * @author QZ
 * @version 1.1.231216a
 * @verified 2016.12.23
 */
class AppProxy
{
	private $_files = null;
	private $_target = '../bing.html?f=', $_filePath = './log/', $_filename = '';
	
	public function __construct($_get, $_files)
	{
		$this->_files = $_files;
		$this->_filename = date('Ymd').'_'.AppRandom::str().'.log';
	}
	
	public function exec($fileId = 'log-file')
	{
		$_result = array();
		$_error = '';
		
		// save file, save result to $_result
		// if succeded, then redirect
		// if failed, then show error for 5 seconds, and go back
		// start GOTO
		do {
			// app define
			$_file = new AppFileUpload($this->_files, $fileId);
			if (!$_file) {
				$_error = 'bad file object';
				break;
			}
		
			// verify type
			$r = $_file->validFileType('log');
			if ($r) {
				$_error = 'invalid file type: '.$r;
				break;
			}
		
			// save .log file
			$r = $_file->saveToFile($this->_filename, $this->_filePath);
			if ($r) {
				$_error = 'filed to save file: '.$r;
				break;
			}
		
			// clean up
			unset($_file);
			
		} while(0); // end GOTO

		// debug use only
		//var_dump($this);

		// prepare RESULT
		if ($_error) {
			$_result['err'] = $_error;
			$_result['target'] = $this->_target;
		} else {
			$_result['target'] = $this->_target.$this->_filename;
		}
		
		return $_result;
	}
}

?>
