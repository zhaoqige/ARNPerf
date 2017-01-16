<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';

/**
 * Limit Application: ajax/proxy
 *
 * @author QZ
 * @version 1.1.301116a
 * @verified 2016.11.30
 */
interface IApp
{
	public function __construct($config);
	public function exec($env);
}

?>