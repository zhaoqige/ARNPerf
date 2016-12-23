<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';

/**
 * Limit
 *
 * @author QZ
 * @version 1.1.301116a
 * @verified 2016.11.30
 */
interface IFileUpload
{
	public function saveToFile($path = './');
	public function validFileType($type = 'png');
}

?>
