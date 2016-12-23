<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';
require_once 'Limit.Data.php';

/**
 * PHP7, PHP >= 5.2.0, PECL json >= 1.2.0
 *
 * @desc	json_encode(), json_decode()
 * @author 	QZ
 * @version 1.1.301116a
 * @verified 2016.11.30
 */
final class JSON implements IDataFormat
{
	static public function decode($jsonString, $opt = true)
	{
		$_result = array();

		if ($jsonString) {
			// UTF-8 first 2 BOM bytes
			$jsonString = trim($jsonString, chr(239).chr(187).chr(191));
			if (function_exists('json_decode')) {
				$_result = @ json_decode($jsonString, $opt);
			}
		}

		return $_result;
	}

	static public function encode($keyedArray, $opt = null)
	{
		$_result = '';

		if (function_exists('json_encode')) {
			$_result = @ json_encode($keyedArray, $opt);
		}

		return $_result;
	}
}

?>
