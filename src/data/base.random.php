<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';
require_once 'limit.random.php';


class AppRandom implements IRandom
{
	static public function num($length = 6)
	{
		$num = intval("0".rand(1,9).rand(0,9).rand(0,9).rand(0,9).rand(0,9));
		return $num;
	}

	static public function str($length = 6)
	{
		$str = chr(rand(65,90)).chr(rand(65,90)).chr(rand(65,90)).chr(rand(65,90)).chr(rand(65,90)).chr(rand(65,90));
		return $str;
	}
}

?>
