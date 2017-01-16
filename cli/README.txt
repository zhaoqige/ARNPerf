v160117:
1. Change .log format;
2. Add .log file upload.

v220715:
1. Added interval time calculation.


How to use:
1. Install GPS Windows Driver;
2. Install ActivePerl;
3. Use ActivePerl PPM to install Net::SSH2 (Exec "ppm install Net-SSH2.PPD" in CMD), W32::SerialPort;

4. Run "./cli/" scripts during testing, execute like "perl gps_win.pl COM10" & "perl field_win.pl 192.168.1.24 01d24s44.log".

5. Copy "./ui/" to support PHP5 http service root, rename it to "field6"; use Chrome/Firefox to visit "http://<http_ip>/field6/bing.html"; click "File ..." button, select your .log file, then click "Go !"

	Take this as example:
	Eg. "http://192.168.1.2/field6/bing.html"

FAQ:
1. You should run "perl gps_win.pl" like this:
	"> gps_win.pl COM10"

2. You should run "perl field_win.pl" like this:
	"> afl_win.pl 192.168.1.24 01d24s49.log"

3. Error "Can't call method "shell" on an undefined value at field_win.pl line ..."
	You need to check if the SSH login password is "field6".