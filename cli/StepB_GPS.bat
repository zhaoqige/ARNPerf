@echo off
title "ARNPerf v7.0.121017-py"
set DIR=%cd%
set /p conf="Search automatically: y/N ? "

if "%conf%" == "" goto arnperf7user
if "%conf%" == "n" goto arnperf7user
if "%conf%" == "N" goto arnperf7user

:arnperf7search
echo * ARNPerf GPS search: enabled
python %DIR%\GPS.py
pause
exit

:arnperf7user
set /p num="Enter GPS Sensor: (com4) com"
if "%num%" == "" set num=4
python %DIR%\GPS.py com"%num%"

pause
exit

