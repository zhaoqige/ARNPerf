<?php


interface IApp
{
	public function __construct($config);
	public function exec($env);
}

?>