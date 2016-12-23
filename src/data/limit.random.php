<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';

/**
 * Limit Random
 *
 * @author QZ
 * @version 1.1.301116a
 * @verified 2016.11.30
 */
interface IRandom
{
	static public function str($length = 6);
	static public function num($length = 6);
}

?>
