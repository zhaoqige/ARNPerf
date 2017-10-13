@echo off
title "ARNPerf v7.0.121017-py"
set DIR=%cd%
set /p conf="Search automatically: Y/n ? "

if "%conf%" == "" goto arnperf7search
if "%conf%" == "y" goto arnperf7search
if "%conf%" == "Y" goto arnperf7search

:arnperf7user
set /p num="Enter GPS Sensor: (com4) com"
if "%num%" == "" set num=4
%DIR%\GPS.py com"%num%"

pause
exit

:arnperf7search
echo * ARNPerf GPS search: enabled
%DIR%\GPS.py

echo
pause
exit
