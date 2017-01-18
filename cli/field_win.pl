#!/bin/bin/env perl
#
# by Qige @ 2017.01.16/2017.01.17/2017.01.18
#
# define params;
# read user input;
# print welcome;
# start SSH connection;
# prepare .log file;
# start main loop;
# - get GPS locations;
# - calc GPS BAR;
# - read baseband info when pass BAR;
# - save to .log file;
# - again;
# free up.
#

#use warnings; 
use strict;

use Net::SSH2;
use Time::HiRes qw(gettimeofday);


# Configurations
my %app_conf = (
	app_v => 'vWin180117 Field6CLI',
	app_conf => 'field6.conf',

	gps_file => 'gps.txt',
	gps_fence => 0.0002, #  ~= 10m
	gps_fix_lat => 0,
	gps_fix_lng => 0,

	ssh_host => '192.168.1.100',
	ssh_user => 'root',
	ssh_passwd => 'root',
	#ssh_passwd => 'field6',
	ssh_port => 22,
	#ssh_port => 1440,

	kpi_log => '_cache.log',
	kpi_note => 'FreerunCache',
	kpi_location => 'BeijingOffice',
	kpi_nw_if => 'eth0',
	kpi_wls_if => 'wlan0'
);



# init & load field6.conf
&conf_init(\%app_conf, @ARGV);

# DEBUG USE ONLY
#my @_args = ('192.168.1.2','d02s44.log','debug','Beijing Office'); # DEBUG USE ONLY
#&conf_init(\%app_conf, @_args);
# DEBUG USE ONLY



# ...
&print_version($app_conf{app_v}, $app_conf{ssh_host}, $app_conf{kpi_log});



# try ssh connection first
my $ssh;
my $ssh_target = sprintf "%s:%s@%s:%s",
					$app_conf{ssh_user}, $app_conf{ssh_passwd},
					$app_conf{ssh_host}, $app_conf{ssh_port};
print "Trying SSH to host $ssh_target, please wait ...\n";
$ssh = &ssh_try($app_conf{ssh_host}, $app_conf{ssh_port}, $app_conf{ssh_user}, $app_conf{ssh_passwd});
#print "dbg> $ssh\n";



# start communication
# server -> welcome banner
# loop:
# * client -> send command
# * server -> send result

# iwinfo, ifconfig
my $_cmd = "wiw=`iwinfo $app_conf{kpi_wls_if} i | tr -s '\n' '|'`; echo \$wiw | cut -d '|' -f 2 | cut -d ' ' -f 4; echo \$wiw | cut -d '|' -f 5 | cut -d ' ' -f 3; echo \$wiw | cut -d '|' -f 5 | cut -d ' ' -f 5; echo \$wiw | cut -d '|' -f 5 | cut -d ' ' -f 6; echo \$wiw | cut -d '|' -f 6 | cut -d ':' -f 2 | cut -d ' ' -f 2; wnw=`ifconfig $app_conf{kpi_nw_if} | tr -s '\n' '|'`; echo \$wnw | cut -d '|' -f 1 | cut -d ' ' -f 5; echo \$wnw | cut -d '|' -f 6 | cut -d ' ' -f 3 | cut -d ':' -f 2; echo \$wnw | cut -d '|' -f 6 | cut -d ' ' -f 7 | cut -d ':' -f 2\n";

# result from SSH, split in lines
my @output;

# read welcome banner
@output = &ssh_read($ssh);
#print "dbg> \n@output\n";


# main loop
my %kpi_last = ( rxb => 0, txb => 0, ts_s => 0, ts_us => 0);
my %gps_last = ( valid => 'V', lat => 0, lng => 0, speed => 0, heading => 0 ); # save last gps pos

# run loop, and never quit
for(;;) {
	# empty data
	undef @output;
	
	
	# update kpi from device ssh
	my %kpi = &kpi_update($ssh, $_cmd, 1);

	# print current kpi
	&print_kpi(\%kpi, \%kpi_last);


	# read GPS pos
	my %gps_crt = &gps_pos($app_conf{gps_file});

	# print current gps pos
	&gps_print(%gps_crt);

	# calc gps fence, decide to write kpi to log file
	# 3> lost GPS
	# 2> recover GPS
	# 1> pass GPS FENCE
	# 0> inside GPS FENCE
	my $_flag_gps = &gps_calc(\%app_conf, \%gps_crt, \%gps_last);
	
	
	# save log according to GPS calc
	if ($_flag_gps) {
		&log_calc($_flag_gps, \%app_conf, \%kpi, \%gps_crt);
	}
	

	# prepare for next round
	undef %kpi;
	undef %gps_crt;
	
	# idle
	sleep 1;
}

&ssh_close(\$ssh);
# END OF EXECUTION



# print version
# print usage when missing params
sub print_version {
	my ($v, $_host, $_log) = @_;
	print "Version: $v, by 6Harmonics Qige @ 2017.01.17\n";
	
	die "\n =-= NO HOST IP ASSIGNED =-=\n > perl field_win.pl 192.168.1.24 01d24s44.log\n"
		unless($_host);
		
	die "\n=-= NO LOG FILE NAME ASSIGNED =-=\n > perl field_win.pl 192.168.1.24 01d24s44.log\n"
		unless($_log);
}

# send cmd to device, read result
# parse result
# save current ts (%s.%us)
sub kpi_update {
	my %kpi;
	my @output;
	my ($_bssid, $_signal, $_noise, $_noise2, $_br, $_mac, $_rxb, $_txb);
	my ($start_s, $start_us) = 0;
	
	my ($_ssh, $_cmd, $_idle) = @_;
	
	ssh_write($_ssh, $_cmd);
	sleep ($_idle || 1);
	# = ssh_read($ssh);
	@output = ssh_read($_ssh);
	chomp(@output);
	
	if (@output) {
		#printf "dbg> %s\n%s\n", $_cmd, @output;
		if ($#output == 7) {
			($_bssid, $_signal, $_noise, $_noise2, $_br, $_mac, $_rxb, $_txb) = @output;
			$_br /= 4;
			if ($_signal =~ 'unknown') {
				%kpi = (
					mac => $_mac || '',
					bssid => $_bssid || '',
					signal => 0,
					noise => $_noise || 0,
					br => $_br || 0,
					rxb => $_rxb || 0,
					txb => $_txb || 0,
					time_gap => 1
				);
			} else {
				%kpi = (
					mac => $_mac || '',
					bssid => $_bssid || '',
					signal => $_signal || 0,
					noise => $_noise2 || 0,
					br => $_br || 0,
					rxb => $_rxb || 0,
					txb => $_txb || 0,
					time_gap => 1
				);
			}
		}
	}
	
	# save current ts: %s.%us
	($start_s, $start_us) = gettimeofday();
	$kpi{ts_s} = $start_s;
	$kpi{ts_us} = $start_us;
	

	return %kpi;
}



# calc kpi (time interval)
# print kpi
# save
sub print_kpi {
	my ($_kpi, $_kpi_last) = @_;

	my ($_mac, $_bssid, $_peer) = '';
	my ($_signal, $_noise, $_snr, $_rxb, $_rxb_last, $_txb, $_txb_last, $_br) = 0;
	
	my %thrpt = ( rx_thrpt => 0, tx_thrpt => 0, rxb => 0, txb => 0, _rxb => 0, _txb => 0, intl => 0 );
	
	
	# check data first
	$_mac = $$_kpi{mac}; $_bssid = $$_kpi{bssid};
	$_peer = $$_kpi{peer} || '';
	$_signal = $$_kpi{signal};
	$_noise = $$_kpi{noise};
	if ($_signal) {
		$_snr = $_signal - $_noise;
	} else {
		$_snr = 0;
	}
	$_br = $$_kpi{br}; $_rxb = $$_kpi{rxb}; $_txb = $$_kpi{txb};
	
	$_rxb_last = $$_kpi_last{rxb}; $_txb_last = $$_kpi_last{txb};
	
	$thrpt{rxb} = $_rxb;
	$thrpt{txb} = $_txb;
	$thrpt{_rxb} = $_rxb_last;
	$thrpt{_txb} = $_txb_last;
	
	$thrpt{start_s} = $$_kpi{ts_s};
	$thrpt{start_us} = $$_kpi{ts_us};
	$thrpt{stop_s} = $$_kpi_last{ts_s};
	$thrpt{stop_us} = $$_kpi_last{ts_us};
	
	# send to calc
	&kpi_thrpt_calc(\%thrpt);
	
	
	# clear screen
	system "cls";
	print "\n";

	print " -------- -------- -------- -------- -------- --------\n";
	print "                     Field6CLI \n";	
	print "        https://github.com/zhaoqige/field6.git \n";	
	print " -------- -------- -------- -------- -------- --------\n";
	printf "             MAC: %s\n\n", $_mac ? $_mac : '00:00:00:00:00:00';	
	
	printf "           BSSID: %s\n", $_bssid ? $_bssid : '00:00:00:00:00:00';
	printf "    Signal/Noise: %d/%d dBm, SNR = %d\n", $_signal, $_noise, $_snr;	
	printf "         Bitrate: %.3f Mbit/s\n", $_br;
	printf "      Throughput: Rx = %.3f Mbps, Tx = %.3f Mbps\n\n", $thrpt{rx_thrpt}, $thrpt{tx_thrpt};
		
	printf "        interval: %.3fs\n\n", $thrpt{intl};
	
	# save for next time
	$$_kpi{rx_thrpt} = $thrpt{rx_thrpt};
	$$_kpi{tx_thrpt} = $thrpt{tx_thrpt};
	$$_kpi_last{rxb} = $$_kpi{rxb};
	$$_kpi_last{txb} = $$_kpi{txb};
	
	$$_kpi_last{ts_s} = $$_kpi{ts_s};
	$$_kpi_last{ts_us} = $$_kpi{ts_us};
}


# calc time interval, throughput
sub kpi_thrpt_calc {
	my ($_thrpt) = @_;
	
	my ($_start_s, $_start_us, $_stop_s, $_stop_us, $_time_gap) = 0;
	my ($_rx_thrpt, $_tx_thrpt, $_rxb, $_txb, $_rxb_last, $_txb_last);
	$_rxb = $$_thrpt{rxb}; $_txb = $$_thrpt{txb};
	$_rxb_last = $$_thrpt{_rxb}; $_txb_last = $$_thrpt{_txb};
	$_start_s = $$_thrpt{start_s};
	$_start_us = $$_thrpt{start_us};
	$_stop_s = $$_thrpt{stop_s};
	$_stop_us = $$_thrpt{stop_us};

	if ($_rxb_last > 0 and $_txb_last > 0) {
		$_rx_thrpt = ($_rxb - $_rxb_last) * 8 / 1024 / 1024; # unit: Mbps
		$_tx_thrpt = ($_txb - $_txb_last) * 8 / 1024 / 1024;
		
		$_time_gap = ($_start_s + $_start_us/1000000) - ($_stop_s + $_stop_us/1000000);
		#printf " > (interval %.3f s)\n", $_time_gap;
		$$_thrpt{intl} = $_time_gap;
		if ($_time_gap > 0) {
			$_rx_thrpt = $_rx_thrpt / $_time_gap;
			$_tx_thrpt = $_tx_thrpt / $_time_gap;
		}
	} else {
		$_rx_thrpt = $_tx_thrpt = 0;
	}
	
	$$_thrpt{rx_thrpt} = $_rx_thrpt;
	$$_thrpt{tx_thrpt} = $_tx_thrpt;
}


# todo: decide when to write
# $_flag: 3> lost GPS, 2> recover GPS, 1> over FENCE, 0> secure 
sub log_calc {
	my ($_log, $_note, $_location, $_ts);
	my ($_data, $_peer);
	my ($_flag, $_conf, $_kpi, $_gps) = @_;

	printf " >> Data saved (reason %d)\n", $_flag;
	if ($_flag > 0) {
		$_log = $$_conf{kpi_log};
		$_note = $$_conf{kpi_note};
		$_location = $$_conf{kpi_location};
		$_ts = &ts();
		if ($_flag == 2) {
			$_data = "+6w,config,$$_kpi{mac},$_note,$_location\n";
			&log_save($_log, $_data);
		}
		
		#$_data = "+6w,$$_kpi{bssid},$$_gps{lat},$$_gps{lng},$$_kpi{signal},$$_kpi{noise},$$_kpi{rx_thrpt},$$_kpi{tx_thrpt},$$_kpi{br},$$_gps{speed},$$_gps{heading}\n";
		$_data = sprintf "+6w,%s,%s,%.8f,%.8f,%d,%d,%.3f,%.3f,%.1f,%.3f,%d\n", 
					$_ts, $$_kpi{bssid},$$_gps{lat},$$_gps{lng},
					$$_kpi{signal},$$_kpi{noise},$$_kpi{rx_thrpt},$$_kpi{tx_thrpt},$$_kpi{br},
					$$_gps{speed},$$_gps{heading};
		&log_save($_log, $_data);
	}
}

sub log_is_empty {
	my ($_log) = @_;
	my $_text = &file_read_1st_line($_log);
	return (($_text and $_text =~ '') ? 1 : 0);
}

sub log_save {
	my ($_log, $_data) = @_;
	&file_write($_log, $_data);
}

# pass in hash reference
# calc if pass fence
# save gps_crt to gps_last
sub gps_calc {
	my $_result = 0;
	my ($_app_conf, $_gps_crt, $_gps_last) = @_;
	if ($$_gps_crt{valid} =~ /A/) {
		if ($$_gps_last{valid} =~ /A/) {
			#print "dbg> calc FENCE when GPS VALID\n";
			$_result = &gps_calc_fence($$_app_conf{gps_fence}, $$_gps_crt{lat}, $$_gps_crt{lng}, $$_gps_last{lat}, $$_gps_last{lng});
		} else {
			#print "dbg> write when first GPS VALID\n";
			$_result = 2;
		}
	} else {
		$_result = 3;
		#printf "dbg> write when los GPS SIGNAL\n";
	}
  
	printf "\n > (GPS Fence Calculated @ %s)\n", &ts();
	
	# copy values
	$$_gps_last{valid} = $$_gps_crt{valid};
	$$_gps_last{lat} = $$_gps_crt{lat};
	$$_gps_last{lng} = $$_gps_crt{lng};
	$$_gps_last{speed} = $$_gps_crt{speed};
	$$_gps_last{heading} = $$_gps_crt{heading};
	
	return $_result;
}

# limit this gps inside a square of last one
# mark last gps as center, if lat gap + lng gap over bar
# trigger pass fence
sub gps_calc_fence {
	my $_result = 0;
	
	my ($gap_fence, $lat1, $lng1, $lat2, $lng2) = @_;
	my $gap_lat = $lat1 > $lat2 ? ($lat1 - $lat2) : ($lat2 - $lat1);		
	my $gap_lng = $lng1 > $lng2 ? ($lng1 - $lng2) : ($lng2 - $lng1);
	my $gps_gap = $gap_lat - $gap_lng;
	
	if ($gps_gap > $gap_fence) {
		#print "dbg> PASS FENCE\n";
		$_result = 1;
	}
	
	return $_result;
}

# print gps in GCJ-02 format
sub gps_print {
	my (%gps_crt) = @_;
	if ($gps_crt{valid} =~ /A/) {
		printf " GCJ-02: %.8f, %.8f, %.3f km/h, hdg %d\n", $gps_crt{lat}, $gps_crt{lng}, $gps_crt{speed}, $gps_crt{heading};
	} else {
		printf " GCJ-02: =-= UNKNOWN POSITION (%s) =-=\n", $gps_crt{valid};
	}
}


# return ($valid, $lat, $lng, $speed, $hdg)
# set default value when "undef"/NULL
sub gps_pos {
	my %pos;
	my @_result;
	my ($_gps_valid, $_gps_lat, $_gps_lng, $_gps_speed, $_gps_heading);
	my ($_gps_file) = @_;
	my $_line = file_read_1st_line($_gps_file);
	if ($_line) {
		@_result = split ",", $_line;
	} else {
		@_result = split ",", "V,,,,";
	}
	
	($_gps_valid, $_gps_lat, $_gps_lng, $_gps_speed, $_gps_heading) = @_result;
	%pos = ( valid => $_gps_valid || 'V', lat => $_gps_lat || 0, lng => $_gps_lng || 0, speed => $_gps_speed || 0, heading => $_gps_heading || 0 );
	
	return %pos;
}


# get timestamp
sub ts {
	my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	$year += 1900; $mon += 1;
	my $datetime = "$year-$mon-$day $hour:$min:$sec";
	return $datetime;
}

# ...
sub file_exists {
	my ($_filepath) = @_;
	return -e $_filepath;
}

# read all lines
sub file_read_all {
	my @_content;
	my ($_file) = @_;
	if ($_file and file_exists($_file)) {
		open(FD, "<", $_file);
		my @_lines = <FD>;
		close FD;

		@_content = @_lines;
	}
	return @_content;
}


# open & return first line
sub file_read_1st_line {
	my $_line;
	my ($_file) = @_;
	my @_content = file_read_all($_file);
	if (@_content) {
		$_line = $_content[0];
		chomp($_line);
	}
	return $_line;
}

sub file_write {
	my ($_file, $_text) = @_;
	open FILE, ">>$_file";
	printf FILE $_text;
	close FILE;
}


# parse .conf file & user input
sub conf_init {
	my ($_conf, @_argv) = @_;

	my $_conf_file = $$_conf{app_conf};
	my ($_host, $_port, $_user, $_passwd, $_log, $_note, $_location) = &conf_load($_conf_file);
	my ($_uhost, $_ulog, $_unote, $_ulocation) = @_argv;

	# valid & save
	if ($_uhost) {
		$$_conf{ssh_host} = $_uhost;
	} elsif ($_host) {
		$$_conf{ssh_host} = $_host;
	}

	if ($_port) {
		$$_conf{ssh_port} = $_port;
	}

	if ($_user) {
		$$_conf{ssh_user} = $_user;
	}

	if ($_passwd) {
		$$_conf{ssh_passwd} = $_passwd;
	}

	if ($_ulog) {
		$$_conf{kpi_log} = $_ulog;
	} elsif ($_log) {
		$$_conf{kpi_log} = $_log;
	}

	if ($_unote) {
		$$_conf{kpi_note} = $_unote;
	} elsif ($_note) {
		$$_conf{kpi_note} = $_note;
	}

	if ($_ulocation) {
		$$_conf{kpi_location} = $_ulocation;
	} elsif ($_location) {
		$$_conf{kpi_location} = $_location;
	}
}

# read .conf
# sample: "192.168.1.24,user,password,d24cache.log,demo fast,debug location \n"
sub conf_load {
	my @_result;
	my ($_conf_file) = @_;
	my $_line = file_read_1st_line($_conf_file);
	#$_line = chomp($_line);
	if ($_line) {
		@_result = split ",", $_line;
	}
	return @_result;
}


# return ssh2 connection
sub ssh_try {
	my $_result;
	my ($_host, $_port, $_user, $_passwd) = @_;

	my $_ssh = Net::SSH2->new();
	$_ssh->connect($_host, $_port, Timeout => 5);
	if ($_ssh->error()) {
		die "ERROR: Unkown remote\n";
	}

	$_ssh->auth(username => $_user, password => $_passwd);
	if ($_ssh->auth_ok()) {
		print " (host reachable, connected)\n";
	} else {
		die "ERROR: Could not establish SSH connection (invalid user or password)\n";
	}

	$_result = $_ssh->channel();
	$_result->shell();

	return $_result;
}

# read data from ssh2->channel() as line array
sub ssh_read {
	my ($_chan) = @_;
	my @_result = <$_chan>;
	return @_result;
}

# send command to ssh2->channel()
sub ssh_write {
	my ($_chan, $_cmd) = @_;
	print $_chan $_cmd;
}

# close & free up
sub ssh_close {
	my ($_ssh) = @_;
	$$_ssh->close(); # verified @ 2017.01.18
	undef $$_ssh;
}

