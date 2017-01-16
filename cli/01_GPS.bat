@echo off
title "Field v6.0.Q160117"
set DIR=%cd%
set /p num="Enter GPS Module COM Number: 4 "
if "%num%" == "" set num=4
%DIR%\gps_win.pl com"%num%"
pause