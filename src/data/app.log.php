<?php
(!defined('TASKLET_ID')) && exit('404: Page Not Found');

'use strict';
require_once 'limit.app.php';
require_once 'data.csv.php';

/**
 * App Log
 *
 * @desc		parse .log file into array()
 * @author 		QZ
 * @version 	1.1.231216a
 * @verified 	2016.12.23
 */
class AppLog implements IApp
{
	private $_fileHandle = null, $_filePath = './log/', $_filename = '', $_assort = 1;
	private $_limitLineSizeMax = 1024;
	
	private $_pointStat = null;
	
	public function __construct($env = null)
	{
		if (is_array($env)) {
			if (key_exists('file', $env)) {
				$this->_filename = $this->_filePath.$env['file'];
			}
			if (key_exists('type', $env)) {
				$this->_assort = $env['type'];
			}
			if (key_exists('limit', $env)) {
				$this->_limitSizeMax = $env['limit'];
			}
		}
		
		$this->_pointStat = array(
				'bad' => 0,
				'weak' => 0,
				'normal' => 0,
				'strong' => 0,
				'total' => 0
		);
	}
	
	public function exec($type = 1)
	{
		$_result = null;
		
		$error = '';
		do { // start GOTO
			// check if file exists
			if (! file_exists($this->_filename)) {
				$error = 'invalid file';
				break;
			}
			
			$this->_fileHandle = fopen($this->_filename, 'r');
			if (! $this->_fileHandle) {
				$error = 'cannot open file';
				break;
			}
			
			// prepare $_result;
			$_result = array();
			
			$i = 0; $buffer = '';
			$dev = $map = $line = array();
			
			do {
				// parse line by line
				$buffer = fgets($this->_fileHandle, $this->_limitLineSizeMax);
				if (strstr($buffer, 'config')) {
					$line = CSV::decode($buffer);
					
					list($mark, $config, $mac, $peer, $title, $note) = $line;
					
					$dev['mac'] = $mac;
					$dev['peer'] = $peer;
					$dev['title'] = $title;
					$dev['note'] = $note;
					
				} else if (strstr($buffer, '+6w')) {
					$line = CSV::decode($buffer);
					list($mark, $ts, $lat, $lng, $signal, $noise, $rxthrpt, $rxmcs, $txthrpt, $txmcs, $speed) = $line;
					
					// prepare for map center, zoom level
					if ($i) {
						if ($map['lat']['min'] > $lat) $map['lat']['min'] = $lat;
						if ($map['lat']['max'] < $lat) $map['lat']['max'] = $lat;
						if ($map['lng']['min'] > $lng) $map['lng']['min'] = $lng;
						if ($map['lng']['max'] < $lng) $map['lng']['max'] = $lng;
					} else {
						$map['lat']['min'] = $map['lat']['max'] = $lat;
						$map['lng']['min'] = $map['lng']['max'] = $lng;
					}
					
					// save point
					$point = array(
							'ts' => $ts,
							'lat' => $lat, 
							'lng' => $lng,
							'signal' => $signal,
							'noise' => $noise,
							'rx' => $rxthrpt,
							'rxmcs' => $rxmcs,
							'tx' => $txthrpt,
							'txmcs' => $txmcs,
							'speed' => $speed
					);
					$_result['data']['points'][] = $point;
					$this->calcPointStat($point);
					
					$i ++;
				}
			} while(! feof($this->_fileHandle));
			
			$_result['dev'] = $dev;
			$_result['map'] = $this->calcMap($map);
			$_result['data']['pstat'] = $this->_pointStat;
			
			// clean up
			fclose($this->_fileHandle);
			
		} while(0); // end GOTO
		
		if ($error) {
			$_result = array('err' => $error);
		}
		
		// debug use only
		//var_dump($_result);
		
		return $_result;
	}
	
	private function calcMap($map)
	{
		$_result = array();
		
		$latMin = $map['lat']['min']; $latMax = $map['lat']['max'];
		$lngMin = $map['lng']['min']; $lngMax = $map['lng']['max'];

		$latGap = $latMax - $latMin;
		$lngGap = $lngMax - $lngMin;
		$gap = max($latGap, $lngGap);
		
		// FIXME: zoom level calibrate
		$zoom = 16;
		if ($gap < 0.12)	$zoom = 14;
		if ($gap < 0.07)	$zoom = 15;
		if ($gap < 0.03) 	$zoom = 16;
		if ($gap < 0.004) 	$zoom = 17;
		if ($gap < 0.0003) 	$zoom = 18;
		
		$_result['center']['lat'] = ($latMin + $latMax) / 2;
		$_result['center']['lng'] = ($lngMin + $lngMax) / 2;
		
		$_result['gap']['lat'] = (float) number_format($latGap, 8);
		$_result['gap']['lng'] = (float) number_format($lngGap, 8);
		$_result['zoom'] = $zoom;
		
		return $_result;
	}
	
	private function calcPointStat($point)
	{
		switch($this->_assort) {
			case 4:
				$this->calcPointByPER($point);
				break;
			case 3:
				$this->calcPointByNoise($point);
				break;
			case 2:
				$this->calcPointBySNR($point);
				break;
			case 1:
			default:
				$this->calcPointByThrpt($point);
				break;
		}
		$this->_pointStat['total'] ++; // total
	}
	
	private function calcPointByThrpt($point)
	{
		$thrpt = $point['tx'] + $point['rx'];
		if ($thrpt < 0.3)						$this->_pointStat['bad'] ++;
		if ($thrpt >= 0.3 && $thrpt < 0.8) 		$this->_pointStat['weak'] ++;
		if ($thrpt >= 0.8 && $thrpt < 1500) 	$this->_pointStat['normal'] ++;
		if ($thrpt >= 1500) 					$this->_pointStat['strong'] ++;
	}
	
	private function calcPointBySNR($point)
	{
		$snr = $point['signal'] - $point['noise'];
		if ($snr < 6) 							$this->_pointStat['bad'] ++;
		if ($snr >= 6 && $snr < 12) 			$this->_pointStat['weak'] ++;
		if ($snr >= 12 && $snr < 24) 			$this->_pointStat['normal'] ++;
		if ($snr >= 24) 						$this->_pointStat['strong'] ++;
	}
	private function calcPointByNoise($point)
	{
		$noise = $point['noise'];
		if ($noise >= -60) 						$this->_pointStat['bad'] ++;
		if ($noise < -60 && $noise >= -90) 		$this->_pointStat['weak'] ++;
		if ($noise < -90 && $noise >= -95) 		$this->_pointStat['normal'] ++;
		if ($noise < -95)				 		$this->_pointStat['strong'] ++;
	}
	private function calcPointByPER($point)
	{
		// TODO: add PER support for ART2 test
		$this->_pointStat['strong'] ++;
	}
}

?>
