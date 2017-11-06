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
 * @version 	1.1.231216a/1.1.180117/1.2.061117 (BingMaps SDK Async)
 * @verified 	2016.12.23/2017.01.18/2017.11.06
 */
class AppLog implements IApp
{
	private $_snrGroundFix = 8;
  private $_fixLat = 0.00125, $_fixLng = 0.00605; // v1.2.061117
	
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
					
					list($mark, $config, $mac, $title, $note) = $line;
					
					$dev['mac'] = $mac;
					$dev['title'] = $title;
					$dev['note'] = $note;
					
				} else if (strstr($buffer, '+6w')) {
					$line = CSV::decode($buffer);
					list($mark, $ts, $bssid, $lat, $lng, $signal, $noise, $rx_thrpt, $rxmcs, $tx_thrpt, $txmcs, $speed) = $line;
          
          // v1.2.061117
          $lat += $this->_fixLat; $lng += $this->_fixLng; 
					
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

					// in case min = 0; bug fix @ 2017.10.11
					if ($map['lat']['min'] == 0) $map['lat']['min'] = $lat;
					if ($map['lng']['min'] == 0) $map['lng']['min'] = $lng;

					// save point
					$point = array(
							'ts' => $ts,
							'lat' => $lat, 
							'lng' => $lng,
              'bssid' => $bssid,
							'signal' => $signal,
							'noise' => $noise,
							'rx' => number_format((float) $rx_thrpt, 3),
							'tx' => number_format((float) $tx_thrpt, 3),
							'rxmcs' => $rxmcs,
							'txmcs' => $txmcs,
							'speed' => $speed
					);
					
					$this->calcPointStat($point);
					$_result['data']['points'][] = $point;
					
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
	
	private function calcPointStat(& $point)
	{
		$level = 0;
		switch($this->_assort) {
			case 4:
				$level = $this->calcPointByPER($point);
				break;
			case 3:
				$level = $this->calcPointByNoise($point);
				break;
			case 2:
				$level = $this->calcPointBySNR($point);
				break;
			case 1:
			default:
				$level = $this->calcPointByThrpt($point);
				break;
		}
		
		if ($level >= 7) 	$level = 7;
		if ($level < 0)		$level = 0;
		switch($level) {
			case 7:
			case 6:
			case 5:
			case 4:
				$this->_pointStat['strong'] ++;
				break;
			case 3:
			case 2:
				$this->_pointStat['normal'] ++;
				break;
			case 1:
				$this->_pointStat['weak'] ++;
				break;
			case 0:
			default:
				$this->_pointStat['bad'] ++;
				break;
		}
		$point['level'] = $level;
		$this->_pointStat['total'] ++; // total
	}
	
	private function calcPointByThrpt($point)
	{
		$level = 0;
		
		$thrpt = $point['tx'] + $point['rx'];
		if ($thrpt < 0.3)						$level = 0;
		if ($thrpt >= 0.3 && $thrpt < 0.8) 		$level = 1;
		if ($thrpt >= 0.8 && $thrpt < 1.5) 		$level = 2;
		if ($thrpt >= 1.5 && $thrpt < 2.0) 		$level = 3;
		if ($thrpt >= 2.0 && $thrpt < 2.5) 		$level = 4;
		if ($thrpt >= 2.5 && $thrpt < 3.0) 		$level = 5;
		if ($thrpt >= 3.0 && $thrpt < 4.0) 		$level = 6;
		if ($thrpt >= 4.0) 						$level = 7;
		
		return $level;
	}
	
	private function calcPointBySNR($point)
	{
		$snr = $point['signal'] - $point['noise'];
		
		// snr calibrate
		$snr -= $this->_snrGroundFix; 
		
		$level = 0;
		if ($snr < 6) 							$level = 0;
		if ($snr >= 6 && $snr < 12) 			$level = 1;
		if ($snr >= 12 && $snr < 18) 			$level = 2;
		if ($snr >= 18 && $snr < 24) 			$level = 3;
		if ($snr >= 24 && $snr < 30) 			$level = 4;
		if ($snr >= 30 && $snr < 36) 			$level = 5;
		if ($snr >= 36 && $snr < 42) 			$level = 6;
		if ($snr >= 42) 						$level = 7;
		
		return $level;
	}
	private function calcPointByNoise($point)
	{
		$noise = $point['noise'];
		
		$level = 0;
		if ($noise >= -60) 						$level = 0;
		if ($noise < -60 && $noise >= -70) 		$level = 2;
		if ($noise < -70 && $noise >= -80) 		$level = 3;
		if ($noise < -80 && $noise >= -90) 		$level = 4;
		if ($noise < -90 && $noise >= -95) 		$level = 5;
		if ($noise < -95)				 		$level = 6;
		
		return $level;
	}
	private function calcPointByPER($point)
	{
		// TODO: add PER support for ART2 test
		return 7;
	}
}

?>