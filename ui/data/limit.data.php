<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';

/**
 * Limit Data Format of .ini/json/xml/csv, etc.
 *
 * @author QZ
 * @version 1.1.301116a
 * @verified 2016.11.30
 */
interface IDataFormat
{
	static public function decode($string);
	static public function encode($keyedArray);
}

?>
