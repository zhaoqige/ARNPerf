<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';

/**
 * @desc	Replace insecure string before send to any component
 * @desc	> replace " ", "*", ";"
 *
 * @author 	QZ
 * @version 1.1.301116 2016.08.29/2016.11.30/2016.12.01
 * @verified 2016.11.30
 */
class Filter
{
	// FIXME: maybe filter ' ' is enough
	static private $_filterArray = array(' ','*',';');

	// filter whole array, secure array/string
	// recursively secure string
	static public function secureArray($keyedArray)
	{
		foreach($keyedArray as $key => & $value) {
			if (is_array($value)) {
				$value = self::secureArray($value);
			} else {
				$value = self::secureString($value);
			}
		}

		//print_r($keyedArray);
		return $keyedArray;
	}

	// secure string
	static public function secureString($string)
	{
		$string = str_replace(self::$_filterArray, '', trim($string));
		return $string;
	}

	// check if key exists, if not, assign default value
	static public function getSecureValue($array, $key, $default = '')
	{
		$_result = '';

		if (is_array($array) && array_key_exists($key, $array)) {
			$_result = self::secureString($array[$key]);
		} else {
			$_result = $default;
		}

		return $_result;
	}

	static public function getSecureIndexedValue($array, $index = 0, $default = '')
	{
		$_result = '';

		if (count($array) > $index) {
			$_result = self::secureString($array[$index]);
		} else {
			$_result = $default;
		}

		return $_result;
	}
}

?>
