<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';
require_once 'limit.file.php';


/**
 * File upload
 *
 * @author QZ
 * @version 1.1.231216a
 * @verified 2016.12.23
 */
final class AppFileUpload implements IFileUpload
{
	private $_fileId = '';
	private $_files = null;
	private $_saved = array();
	
	private $_limitSizeMax = 1024000;

	public function __construct($files = null, $fileId = '')
	{
		if (is_array($files) && key_exists($fileId, $files)) {
			$this->_fileId =$fileId;
			$this->_files = $files;
		}
	}
	
	public function init($files, $fileId = 'log-file')
	{
		$this->_files = $files;
		$this->_fileId = $fileId;
	}

	public function saveToFile($filename = '', $path = '')
	{
		$id = $this->_fileId;
		$files = $this->_files;
		$target = $path.$filename;
		$errno = $files[$id]['error'];
		$error = '';
		
		// start GOTO, instead of try()/catch()
		for(;;) {
			if (! $target || file_exists($target)) {
				$error = '';
				break;
			}
			
			if (! @move_uploaded_file($files[$id]['tmp_name'], $target)) {
				$error = 'script: save failed (log 644)?';
				break;
			}
			
			// end GOTO
			break;
		}
		
		return $error;
	}

	public function validFileType($type = 'png')
	{
		$id = $this->_fileId;
		$files = $this->_files;
		$errno = 0;
		$error = '';
		
		// start GOTO, instead of try()/catch()
		do {
			// check environment
			if (! $id || ! $files || ! key_exists($id, $files)) {
				$error = 'file object err'; 
				break;
			}
			
			// check error
			$errno = $files[$id]['error'];
			if ($errno) {
				switch($errno) {
					case UPLOAD_ERR_INI_SIZE:
						$error = 'script: file too big';
						break;
					case UPLOAD_FORM_SIZE:
						$error = 'web: file too big';
						break;
					case UPLOAD_ERR_PARTIAL:
						$error = 'script: file checksum error';
						break;
					case UPLOAD_ERR_NO_FILE:
						$error = 'script: no file detected';
						break;
					case UPLOAD_ERR_NO_TMP_DIR:
						$error = 'script: no tmp dir';
						break;
					case UPLOAD_ERR_CANT_WRITE:
						$error = 'script: write fail';
						break;
					case UPLOAD_ERR_OK:
					default:
						$error = '';
						break;
				}
			}
			if ($errno) break;
			
			// safety check: verify size
			if ($files[$id]['size'] > $this->_limitSizeMax) {
				$error = 'script: file too big';
				break;
			}
			// FIXME: ascii/plain text/text? 
			//safety check: verify type
			// wamp: 'application/octet-stream'
			// lamp: ?
			if ($files[$id]['type'] != 'application/octet-stream') {
				$error = 'script: bad file type';
				break;
			}
		} while(0); // end GOTO
			
		//var_dump($files);
		return $error;
	}
}

?>
