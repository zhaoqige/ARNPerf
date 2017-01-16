<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';


class AppHtml
{
	static public function redirectTo($url = '/', $timeout = 0)
	{
		$html = "<html><head><meta http-equiv='refresh' content='{$timeout};url={$url}' /></head><body></body></html>";
		return $html;
	}
	
	static public function plainText($text = '', $url = '/', $timeout = -1)
	{
		$html = "<html><head><meta http-equiv='refresh' content='{$timeout};url={$url}' /></head><body>{$text}</body></html>";
		return $html;
	}
}

?>
