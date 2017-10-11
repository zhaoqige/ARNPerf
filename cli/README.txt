CHANGE LOG
----------
v7.0-101017:
1. Re-write in Python.

v160117:
1. Change .log format;
2. Add .log file upload.

v220715:
1. Added interval time calculation.


QUICK GUIDE
-----------
1. You can run "StepA_Config.bat" to generate "ARNPerf.conf";
2. Run "StepB_GPS.bat" to start GPS position recording;
3a. If "ARNPerf.conf" file exists, run "StepC_RunARNPerf.bat" directly;
3b. If not, run "StepC_ARNPerf.bat" instead.

DEV ENVIRONMENT DESC
--------------------
Windows7, Python-3.6.3, PySerial-3.4, Paramiko-2.3.1

HOW TO
------
How to use:
1. Install GPS Windows Driver;
2. Install Python;
3. Run these commands in "cmd.exe" after Python installed;
	"pip install pyserial"
	"pip install paramiko"

4. Run "./cli/" scripts during testing, execute (in order) like:
 	"python GPS.py COM10"
	AND
	"python Perf.pl 192.168.1.24 01d24s44.log".

5. Copy "./ui/" to support PHP5 http service root, rename it to "arnperf";
	5.1. Use Chrome/Firefox to visit "http://<http_ip>/arnperf/bing.html";
	5.2. click "File ..." button, select your .log file, then click "Go !"

	Take this as example:
	Eg. "http://192.168.1.2/arnperf/bing.html"

F.A.Q.
------
1. You should run "python GPS.pl" like this:
	"GPS.py COM10"

2. You should run "perl perf_win.pl" like this:
	"Perf.py 192.168.1.24 01d24s49.log"
