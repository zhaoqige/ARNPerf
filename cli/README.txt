CHANGE LOG
----------
v160117:
1. Change .log format;
2. Add .log file upload.

v220715:
1. Added interval time calculation.


QUICK GUIDE
-----------
1. You can use "StepA_Config.bat" to generate "ARNPerf.conf";
2. Run "StepB_GPS.bat" right away;
3a. If "ARNPerf.conf" file exists, run "StepC_RunARNPerf.bat" directly;
3b. If not, run "StepB_GPS.bat" instead.


HOW TO
------
How to use:
1. Install GPS Windows Driver;
2. Install ActivePerl;
3. Use ActivePerl PPM to install Net::SSH2 (Exec "ppm install Net-SSH2.PPD" in CMD), W32::SerialPort;

4. Run "./cli/" scripts during testing, execute like "perl gps_win.pl COM10" & "perl perf_win.pl 192.168.1.24 01d24s44.log".

5. Copy "./ui/" to support PHP5 http service root, rename it to "arnperf"; use Chrome/Firefox to visit "http://<http_ip>/arnperf/bing.html"; click "File ..." button, select your .log file, then click "Go !"

	Take this as example:
	Eg. "http://192.168.1.2/arnperf/bing.html"

F.A.Q.
------
1. You should run "perl gps_win.pl" like this:
	"> gps_win.pl COM10"

2. You should run "perl perf_win.pl" like this:
	"> perf_win.pl 192.168.1.24 01d24s49.log"

3. Error "Can't call method "shell" on an undefined value at perf_win.pl line ..."
	You need to check if the SSH login password is "arnperf".
