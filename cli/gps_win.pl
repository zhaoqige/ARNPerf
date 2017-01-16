#!/bin/bin/env perl
use warnings;
use strict;

require 5.003;
use Win32::SerialPort qw( :PARAM :STAT 0.20 );
use POSIX;

my $aflv = 'vWin151104ON uBlox';


my $spname = $ARGV[0];
my $gpsfile = 'gps.txt';

# Pos fix in Beijing
#my $lat_fix = 0.0012;
#my $lng_fix = 0.0061;

# Pos fix in Ottawa
my $lat_fix = 0;
my $lng_fix = 0;

my $count_in = 0;
my $in_bytes = 1024;
my $string_in;


print " Version: $aflv, by 6Harmonics Qige\n";
die "\n =-= NO GPS COM PORT ASSIGNED =-=\n > perl gps_win.pl COM10\n" unless($spname);
print " - COM: $spname\n\n";


# Set SerialPort
my $sp = new Win32::SerialPort($spname)
	|| die "* Cannot open $spname: $^E\n";

$sp->databits(8);
$sp->parity('none');
$sp->stopbits(1);
$sp->handshake('none');


# u-Blox
# /dev/ttyACM0
$sp->baudrate(115200);
#$sp->write_settings || die "* Cannot write settings.\n";


my $i = 0;
my ($gprmc,$proto,$utc,$v,$gps_lat,$lat,$lati,$ns,$gps_lng,$lng,$lngi,$ew,$speed,$heading,$ymd) = 0;
my $line;
for(;;) {
	$line = $string_in = '';
	($count_in, $string_in) = $sp->read($in_bytes);
	chomp $string_in;
	open GPRMC, '<', \$string_in;
	while($line = <GPRMC>) {
		if ($line =~ /^\$GPRMC/gi) {
			print $line;
			open GPSPOS, ">$gpsfile";
			($proto,$utc,$v,$lat,$ns,$lng,$ew,$speed,$heading,$ymd) = split ',',$line;
			if ($v and $v =~ /A/gi) {
				$ymd or $ymd = '';
				$utc or $utc = '';

				$lati = int($lat/100);
				$lat = ($lat-$lati*100)/60 + $lat_fix;
				$lngi = int($lng/100);
				$lng = ($lng-$lngi*100)/60 + $lng_fix;
				$speed *= 1.852;
				if ($ns and $ns =~ /S/gi) {
					$gps_lat = 0 - ($lati+$lat);
				} else {
					$gps_lat = $lati+$lat;
				}
				if ($ew and $ew =~ /W/gi) {
					$gps_lng = 0 - ($lngi+$lng);
				} else {
					$gps_lng = $lngi+$lng;
				}
				printf "GCJ-02: $ymd $utc, $v, %.8f, %.8f, $speed, $heading\n", $gps_lat, $gps_lng;
				printf GPSPOS "$v,%.8f,%.8f,$speed,$heading\n", $gps_lat, $gps_lng;
			} else {
				printf " -== INVALID POSITION (%s) ==-\n", $v ? $v : "V";
				$v and !($v =~ /V/gi) and printf " (DEBUG START) %s\n (DEBUG END)\n", $line;
				print GPSPOS "#,,,,";
			}
			close GPSPOS;
		}
	}
	close GPRMC;
	
	sleep 1;
	$i ++;
}

$sp->close || die "* failed to close.\n";
undef $sp;