#!/bin/bin/env perl


# 
# iwinfo wlan0 i
# ifconfig br-lan
#

#use warnings;
use strict;

use Net::SSH2;
use Time::HiRes qw(gettimeofday);


my $aflv = 'vWin160117 Field6CLI';

# Define Common Params
my $gpsfile = 'gps.txt';
my $gpst = 0.0002; #  ~= 10m
my $_lat = 0; my $_lng = 0;

my $user = 'root';
my $passwd = 'field6';

my $nwifname = 'eth0';
my $wlsifname = 'wlan0';


my $host = $ARGV[0];
my $logfile = $ARGV[1];
my $note = $ARGV[2];
my $location = $ARGV[3];



print " Version: $aflv, by 6Harmonics Qige\n";
die "\n =-= NO HOST IP ASSIGNED =-=\n > perl field_win.pl 192.168.1.24 01d24s44.log\n" unless($host);
die " =-= NO LOG FILE NAME ASSIGNED =-=\n > perl field_win.pl 192.168.1.24 01d24s44.log\n" unless($logfile);

# start SSH connection
my @welcome;
my $ssh2, $chan2;

print " - host: $host, log: $logfile\n\n";
print " - connecting to host $host: "; # Connecting Host via SSH

$ssh2 = Net::SSH2->new();
$ssh2->timeout(5000);
# $ssh2->connect("$host:22");
$ssh2->connect("$host:1440");
$ssh2->auth(username => $user, password => $passwd);

if ($ssh2->auth_ok()) {
	print "connected.\n";
} else {
	print "*** failed ***.\n";
}

$chan2 = $ssh2->channel();
$chan2->shell();

@welcome = <$chan2>;
sleep 1;


# Enter Main Loop
my $line;
my @output;

my ($_txbytes,$txbytes,$txb,$_rxbytes,$rxbytes,$rxb) = 0;

my $mac = '00:00:00:00:00:00'; my $pmac = '00:00:00:00:00:00'; 
my ($signal,$noise) = -101; my $snr = 0;
my $br = 0.0;
my ($v,$lat,$lng,$speed,$heading) = 0;

my ($startt,$starttu,$endt,$endtu,$intl_time) = 0;
my ($datetime,$sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = 0;

# start Main Loop
for(;;) {
	# Clear screen
	system "cls";
	($startt, $starttu) = gettimeofday();
	
	# Check SSH valid
	if ($ssh2->auth_ok()) {} else { die ' =-= DEVICE UNREACHABLE =-=\n'; }
	
	# Reading GPS Postion
	open(GPSPOS, "<", $gpsfile) || die "=-= Cannot open GPS Position file.\n";
	my @linelist = <GPSPOS>;
	($v,$lat,$lng,$speed,$heading) = split ",", $linelist[0];
	close GPSPOS;
	
	
	
	# Fetching Network Information
	# Fetching Radio Information
	#														  = access point 								  = signal										  = (signal = unknown) noise					  = (signal != unknown) noise					  = br															  = network
	print $chan2 "wiw=`iwinfo $wlsifname i | tr -s '\n' '|'`; echo \$wiw | cut -d '|' -f 2 | cut -d ' ' -f 4; echo \$wiw | cut -d '|' -f 5 | cut -d ' ' -f 3; echo \$wiw | cut -d '|' -f 5 | cut -d ' ' -f 5; echo \$wiw | cut -d '|' -f 5 | cut -d ' ' -f 6; echo \$wiw | cut -d '|' -f 6 | cut -d ':' -f 2 | cut -d ' ' -f 2; wnw=`ifconfig $nwifname | tr -s '\n' '|'`; echo \$wnw | cut -d '|' -f 1 | cut -d ' ' -f 5; echo \$wnw | cut -d '|' -f 6 | cut -d ' ' -f 3 | cut -d ':' -f 2; echo \$wnw | cut -d '|' -f 6 | cut -d ' ' -f 7 | cut -d ':' -f 2\n";
	@output = <$chan2>;
	chomp(@output);
	#foreach $line (@output) { $line and print "$line\n"; }
	

	# calculate
	$pmac 		= $output[0];
	$signal 	= $output[1];
	if ($signal) {
		if ($signal =~ 'unknown') {
			$noise	= $output[2];
		} else {
			$noise	= $output[3];
		}
	} else {
		$noise	= $output[2];
	}
	$br 		= $output[4];
	$mac 		= $output[5];
	$rxbytes 	= $output[6];
	$txbytes 	= $output[7];
	
	($endt, $endtu) = gettimeofday();
	$intl_time = 1+($endt - $startt) + ($endtu - $starttu)/1000000;
	
	if ($_txbytes and $_rxbytes and ($_txbytes > 0 or $_rxbytes > 0)) {
		if ($txbytes and $txbytes > $_txbytes) {
			$txb = ($txbytes - $_txbytes) / 128 / 1024 / $intl_time; # x*8(bit)/1024(K)/1024(M)/intl_time
		}
		if ($rxbytes and $rxbytes > $_rxbytes) {
			$rxb = ($rxbytes - $_rxbytes) / 128 / 1024 / $intl_time; # x*8(bit)/1024(K)/1024(M)/intl_time
		}
	}
	
	
	# get timestamp
	($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst) = localtime(time());
	$year += 1900; $mon += 1;
	$datetime = "$year-$mon-$day $hour:$min:$sec";

	
	# Print KPIs
	printf " -------- -------- -------- -------- -------- --------\n";
	printf "               6Harmonics Ltd. $aflv\n";
	printf " -------- -------- -------- -------- -------- --------\n";
	printf "        Radio: %s\n", $mac ? $mac : '00:00:00:00:00:00';
	printf "         Peer: %s\n", $pmac ? $pmac : '00:00:00:00:00:00';
	if ($signal and $noise) {
		if ($signal =~ 'unknown') {
			printf "     Wireless: unknown, %d dBm, 0\n", $noise;
		} else {
			$snr = $signal - $noise;
			printf "     Wireless: %d dBm, %d dBm, %d\n", $signal, $noise, $snr;
		}
	} else {
		print "     Wireless: unknown, -101 dBm, 0\n";
	}
	if ($br) {
		if ($br =~ 'unknown') {
			printf "      BitRate: %s\n", $br;
		} else {
			printf "      BitRate: %.1f Mbit/s\n", $br;
		}
	} else {
			printf "      BitRate: unknown\n";
	}
	printf "  %s thrpt.: UL %.3f Mbps, DL %.3f Mbps\n\n", $nwifname, $txb, $rxb;
	printf "        -intl: %.3f second(s)\n", $intl_time;
	print " -------- -------- -------- -------- -------- --------\n";
	if ($v =~ /A/) {
			printf "       GCJ-02: %.8f, %.8f, %.3f Km/h\n", $lat, $lng, $speed;
			printf "              ($datetime, $v)\n";
	} else {
			print "       GCJ-02: =-= UNKNOWN POSITION ($v) =-=\n";
	}

	
	# Calculate GPS moving
	if ($lat and $lng) {
    if (abs($lat-$_lat) + abs($lng-$_lng) > $gpst) {
      print "    Recording: $lat, $lng\n";
      open LOGFILE, ">>$logfile";
      printf LOGFILE "+6w:%s,%.8f,%.8f,%s,%d,%.3f,%.3f,%.1f,%s\n", $datetime, $lat, $lng, $signal ? $signal : $noise, $noise, $rxb, $txb, $br, $speed;
      close LOGFILE;
      $_lat = $lat;
      $_lng = $lng;
    }
  } else {
    print "    Recording: $lat, $lng\n";
    open LOGFILE, ">$logfile";
    printf LOGFILE "+6w:config,%s,%s,%s,%s\n", $mac, $pmac, $note, $location
    close LOGFILE;
    $_lat = $lat;
    $_lng = $lng;
  }
	
	
	print "\n\n";
	
	# Save last values
	$_txbytes = $txbytes;
	$_rxbytes = $rxbytes;
	$txb = $rxb = 0;
	@output = '';
	sleep 1;
}

$ssh2->close();
undef $ssh2;