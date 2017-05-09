@echo off
title "ARNPerf v6.1.090517"
set DIR=%cd%
set /p host="Enter host: (default = 192.168.1.24) "
if "%host%" == "" set host=24
set /p log="Enter Log Filename: (d24fast.log) "
if "%log%" == "" set log="d24fast.log"
set /p note="Enter Note: (demo) "
if "%note%" == "" set note="demo"
set /p location="Enter Location: (BQL) "
if "%location%" == "" set location="BQL"
%DIR%\perf_win.pl 192.168.1."%host%" "%log%" "%note%" "%location%"
pause
