#!/bin/bin/env perl
#
# by Qige @ 2017.01.16/2017.01.17/2017.01.18
#
# define params;
# read user input;
# print welcome;
# open GPS;
# main loop;
# - read $GPRMC;
# - parse into hash;
# - print POSITION;
# - write to file;
# - idle
# free up
#

#use warnings; 
use strict;

require 5.003;
use Win32::SerialPort qw( :PARAM :STAT 0.20 );
use POSIX;

# Configurations
my %app_conf = (
	app_v => 'vWin180117 Field6CLI.GPS',

	gps_com => 'com4',
	gps_file => 'gps.txt',

	# Pos in Ottawa
	gps_fix_lat => 0,
	gps_fix_lng => 0,

	# Pos fix in Beijing
	#gps_lat_fix = 0.0012;
	#gps_lng_fix = 0.0061;
	
	bf_rx_length => 1024
);


# init & load
&conf_init(\%app_conf, @ARGV);

# DEBUG USE ONLY
#my @_args = ('com6'); # DEBUG USE ONLY
#&conf_init(\%app_conf, @_args);
# DEBUG USE ONLY



# ...
&print_version($app_conf{app_v}, $app_conf{gps_com}, $app_conf{gps_file});



# try serial port first
my $sp;
printf "Trying open %s, please wait ...\n", $app_conf{gps_com};
$sp = &sp_try($app_conf{gps_com}, 9600);
#print "dbg> $sp\n";


# run loop, and never quit
my $i = 0;
my $gps_file = $app_conf{gps_file};
for(;;) {
	my ($rx_bytes, $buffer) = &sp_read($sp, $app_conf{bf_rx_length});
	my %pos = &gps_parse($rx_bytes, $buffer);
	
	&gps_print(%pos);
	&gps_save($gps_file, %pos);
	
	sleep 1;
	$i ++;
}


&sp_close(\$sp);
# END OF EXECUTION




# parse .conf file & user input
sub conf_init {
	my ($_conf, @_argv) = @_;
	
	my ($_ucom, $_ufile) = @_argv;
	
	if ($_ucom) {
		$$_conf{gps_com} = $_ucom;
	}
	if ($_ufile) {
		$$_conf{gps_file} = $_ufile;
	}
}


# print version
# print usage when missing params
sub print_version {
	my ($v, $_com, $_file) = @_;
	print "Version: $v, by 6Harmonics Qige @ 2017.01.17\n";
	
	die "\n =-= No COM PORT or FILE assigned =-=\n > perl gps_win.pl com4 gps.txt\n"
		unless($_com and $_file);
}


sub gps_parse {
	my %pos_latest = (
		_ts => '',
		valid => 'V',
		lat => 0.0,
		lng => 0.0,
		speed => 0.0,
		heading => 0
	);
	my ($_buffer_length, $_buffer, $_lat_fix, $_lng_fix) = @_;
	
	chomp $_buffer;
	open GPS_RAW, "<", \$_buffer;
	while(my $line = <GPS_RAW>) {
		#chomp $line;
		$line =~ s/[\r\n]//g;
		if ($line =~ /^\$GPRMC/gi) {
			my $ts = &ts();
			printf " -> (RAW data) %s\n ---> %s\n", $ts, $line;
			
			my ($proto,$utc,$v,$lat,$ns,$lng,$ew,$speed,$heading,$ymd) = split ',', $line;
			if ($v and $v =~ /A/gi) {
				my ($gps_lat, $gps_lng, $lat_i, $lng_i);
				$lat_i = int($lat / 100);
				$lat = ($lat - $lat_i * 100) / 60 + $_lat_fix;
				$lng_i = int($lng / 100);
				$lng = ($lng - $lng_i * 100) / 60 + $_lng_fix;
				$speed *= 1.852; # mile to km
				if ($ns and $ns =~ /S/gi) {
					$gps_lat = 0 - ($lat_i + $lat);
				} else {
					$gps_lat = $lat_i + $lat;
				}
				if ($ew and $ew =~ /W/gi) {
					$gps_lng = 0 - ($lng_i + $lng);
				} else {
					$gps_lng = $lng_i + $lng;
				}

				$pos_latest{_ts} = "$ymd $utc" || &ts();
				$pos_latest{valid} = $v || 'V';
				$pos_latest{lat} = $gps_lat || 0;
				$pos_latest{lng} = $gps_lng || 0;
				$pos_latest{speed} = $speed || 0;
				$pos_latest{heading} = $heading || 0;
			}
		}
	}
	close GPS_RAW;
	
	return %pos_latest;
}


sub gps_save {
	my ($_file, %_pos) = @_;
	
	my $_data = sprintf "%s,%0.8f,%0.8f,%0.3f,%d",
			$_pos{valid}, $_pos{lat}, $_pos{lng}, $_pos{speed}, $_pos{heading};
			
	file_write($_file, $_data);
}


# print gps in GCJ-02 format
sub gps_print {
	my (%gps_crt) = @_;
	if ($gps_crt{valid} =~ /A/) {
		printf " > GCJ-02: %.8f, %.8f, %.3f km/h, hdg %d\n", $gps_crt{lat}, $gps_crt{lng}, $gps_crt{speed}, $gps_crt{heading};
	} else {
		printf " > GCJ-02: =-= UNKNOWN POSITION (%s) =-=\n", $gps_crt{valid};
	}
}


sub file_write {
	my ($_file, $_text) = @_;
	open OBJ, ">$_file";
	printf OBJ $_text;
	close OBJ;
}


# return serial port handler;
sub sp_try {
	my $_sp;
	my ($_com, $_baudrate) = @_;
	
	$_sp = new Win32::SerialPort($_com)
		or die "* Cannot open $_com: $^E\n";
	
	$_sp->databits(8);
	$_sp->parity('none');
	$_sp->stopbits(1);
	$_sp->handshake('none');
	
	$_sp->baudrate($_baudrate || 9600);
	
	return $_sp;
}

sub sp_read {
	my ($_sp, $_buffer_length) = @_;
	return $sp->read($_buffer_length);
}


sub sp_close {
	my ($_sp) = @_;
	$$_sp->close()
		or die "* Failed to close sp\n";
	undef $$_sp;
}



# get timestamp
sub ts {
	my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	$year += 1900; $mon += 1;
	my $datetime = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
						$year, $mon, $day, $hour, $min, $sec;
	return $datetime;
}

