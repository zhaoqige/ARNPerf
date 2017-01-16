#!/bin/bin/env perl
#
# by Qige @ 2017.01.16
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


use warnings;
use strict;

use Net::SSH2;
use Time::HiRes qw(gettimeofday);


# Define Common Params
my $v = 'vWin20170116 Field6CLI';

my $conf_file = 'field6.conf';
my $gps_file = 'gps.txt';
my $gps_fense = 0.0002; #  ~= 10m
my $fix_lat = 0; my $fix_lng = 0;

# default params
my $ssh_user = 'root';
my $ssh_passwd = 'root';
# my $ssh_passwd = 'field6';
my $ssh_port = 22;
# my $ssh_port = 1440;

my $data_nw_ifname = 'eth0';
my $data_wls_ifname = 'wlan0';

#my $_host; my $_log; my $_note; my $_location;
my ($_host, $_log, $_note, $_location);
my ($ssh, @welcome, @output);

# check field6.conf file
if (file_exists($conf_file)) {
	open(CONF, "<", $conf_file);
	my @_params = <CONF>;
	($_host, $ssh_port, $ssh_user, $ssh_passwd, $_log, $_note, $_location) = split ",", $_params[0];
}


# read user input
# my ($_ui_host, $_ui_log, $_ui_note, $_ui_location) = @ARGV;
my ($_ui_host, $_ui_log, $_ui_note, $_ui_location);
if (! $_ui_host eq '') {
	$_host = $_ui_host;
}
if (! $_ui_log eq '') {
	$_log = $_ui_log;
}
if (! $_ui_note eq '') {
	$_note = $_ui_note;
}
if (! $_ui_location eq '') {
	$_location = $_ui_location;
}


# welcome
&print_version($v, $_host, $_log);

# try ssh connection first
my $ssh_target = "$ssh_user:$ssh_passwd\@$_host:$ssh_port";
print "Trying SSH to host $ssh_target ... ";
#my $ssh = &ssh_try($_host, $ssh_port, $ssh_user, $ssh_passwd);

print "dbg> $ssh\n";

#my $chan = $ssh->channel();
#$chan->shell();


# read welcome banner
#sleep 1;
#@welcome = ssh_read($chan);
print "dbg> \n@welcome\n";


# check log file
if (&file_exists($_log)) {
	open LOGFILE, ">>$_log";
	printf LOGFILE "+6w:append,%s\n", &current_ts();
}


# main loop
my %gps_last = (
	valid => 'V',
	lat => 0,
	lng => 0,
	speed => 0,
	heading => 0
);

for(;;) {
	# read GPS pos
	my ($_gps_valid, $_gps_lat, $_gps_lng, $_gps_speed, $_gps_heading) = &gps_pos($gps_file);
	my %gps_crt = (
		valid => $_gps_valid,
		lat => $_gps_lat,
		lng => $_gps_lng,
		speed => $_gps_speed,
		heading => $_gps_heading
	);
	
	if ($gps_crt{valid} =~ /A/) {
		printf " GCJ-02: %.8f, %.8f, %.3f Km/h, heading %d\n", $gps_crt{lat}, $gps_crt{lng}, $gps_crt{speed}, $gps_crt{heading};
		if ($gps_last{valid} =~ /A/) {
			print "Double valid";
		} else {
			print "First valid";
		}
		
		%gps_last = %gps_crt;
	} else {
		printf " GCJ-02: =-= UNKNOWN POSITION (%s) =-=\n", $gps_crt{valid};
	}
	
	#ssh_write($chan, "ls /tmp\n");
	#sleep 1;
	#@welcome = ssh_read($chan);
	print "dbg> \n@welcome\n";
	
	sleep 1;
}


#$ssh->close();
undef $ssh;





# print version
# print usage when missing params
sub print_version {
  my ($v, $_host, $_log) = @_;
  print "Version: $v, by 6Harmonics Qige @ 2017.01.16\n";
  die "\n =-= NO HOST IP ASSIGNED =-=\n > perl field_win.pl 192.168.1.24 01d24s44.log\n" unless($_host);
  die "\n=-= NO LOG FILE NAME ASSIGNED =-=\n > perl field_win.pl 192.168.1.24 01d24s44.log\n" unless($_log);
}


# return ssh2 connection
sub ssh_try {
	my $_result;
	my ($_host, $_port, $_user, $_passwd) = @_;

	my $_ssh = Net::SSH2->new();
	$_result = $_ssh->connect($_host, $_port, Timeout => 3);
	if ($_ssh->error() or $_result eq 'undef') {
		die "ERROR: Unkown remote\n";
	}
	
	$_result = $_ssh->auth(username => $_user, password => $_passwd);
	if ($_ssh->auth_ok()) {
		print "(connected)\n";
	} else {
		die "ERROR: Could not establish SSH connection (invalid user or password)\n";
	}
	
	return $_ssh;
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
	#$_ssh->close();
}


sub file_exists {
	my ($_filepath) = @_;
	return -e $_filepath;
}


sub current_ts {
	# get timestamp
	my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	$year += 1900; $mon += 1;
	my $datetime = "$year-$mon-$day $hour:$min:$sec";
	return $datetime;
}

sub gps_pos {
	my ($_gps_pos) = @_;
	
	if (&file_exists($_gps_pos)) {
		open(GPSPOS, "<", $_gps_pos);
	
		my @_gps_lines = <GPSPOS>;
		close GPSPOS;
		
		return split ",", $_gps_lines[0];
	} else {
		return split ",", "V,,,,";
	}
}
