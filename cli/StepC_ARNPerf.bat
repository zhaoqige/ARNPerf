@echo off
title "ARNPerf v7.0.121017-py"
set DIR=%cd%
set /p conf="Use ARNPerf.conf: Y/n ? "

if "%conf%" == "" goto arnperf7conf
if "%conf%" == "y" goto arnperf7conf
if "%conf%" == "Y" goto arnperf7conf

:arnperf7user
set /p hid="Enter Host IP: 192.168.1."
if "%hid%" == "" set hid="24"
set /p log="Enter Log Filename: (d24fast.log) "
if "%log%" == "" set log="d24fast.log"
set /p note="Enter Note: (demo) "
if "%note%" == "" set note="demo"
set /p location="Enter Location: (BQL) "
if "%location%" == "" set location="BQL"
%DIR%\Perf.py 192.168.1."%host%" "%log%" "%note%" "%location%"

echo
pause
exit

:arnperf7conf
echo * using ARNPerf.conf
%DIR%\Perf.py

echo
pause
exit
