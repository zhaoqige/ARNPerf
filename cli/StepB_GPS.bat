@echo off
title "ARNPerf v7.0.101017-py"
set DIR=%cd%
set /p num="Enter GPS Sensor: (COM4) COM"
if "%num%" == "" set num=4
%DIR%\GPS.pl com"%num%"
pause
