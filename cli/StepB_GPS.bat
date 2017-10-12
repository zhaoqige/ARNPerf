@echo off
title "ARNPerf v7.0.101017-py"
set DIR=%cd%
set /p num="Enter GPS Sensor: (COM4) "
if "%num%" == "" (
	%DIR%\GPS.py
)
else
(
	%DIR%\GPS.py com"%num%"
)
pause
