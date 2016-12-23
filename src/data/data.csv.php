<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';
require_once 'Limit.Data.php'; // IDataFormat

/**
 * PHP7, PHP 5, PHP 4
 *
 * NOTE: may need set line buffer before decode();
 * @desc	CSV only support row & col, so max Two-Demensional Array
 * to make sure data not missing, array may change to plain text
 *
 * @author 	QZ
 * @version 1.1.301116a
 * @tested 	2016.11.30
 */
final class CSV implements IDataFormat
{
	static private $_lineBufferLength = 1024;

	static public function decode($csvString, $delim = ",", $lineLimit = 1024)
	{
		$lineNumber = 0;
		$lineArray = $_result = null;

		$lineArray = @ explode("\r\n", $csvString);
		foreach($lineArray as $line) {
			if ($line && is_string($line)) {
				$_result = @ explode($delim, $line);
			}
			$lineNumber ++;
			if ($lineNumber >= $lineLimit)
				break;
		}

		return $_result;
	}

	public function setLineBuffer($length = 1024)
	{
		self::$_lineBufferLength = $length;
	}

	static public function encode($keyedArray, $delim = ",")
	{
		$_line = $_result = '';

		// TODO: make csv string
		if (is_array($keyedArray)) {
			foreach($keyedArray as $_line) {
				if (is_array($_line)) {
					$_line = @ implode($delim, $_line);
				} else if (is_string($_line)) {
					$_line = $_line;
				}

				if ($_line) {
					$_result .= ($_line."\r\n");
				}
				$_line = '';
			}
		}

		return $_result;
	}
}

?>
