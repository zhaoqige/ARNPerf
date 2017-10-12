@echo off
title "ARNPerf v7.0.121017-py"
set DIR=%cd%
set /p num="Enter GPS Sensor: (com4) com"
if "%num%" == "" (
	%DIR%\GPS.py
) else (
	%DIR%\GPS.py com"%num%"
)
pause
