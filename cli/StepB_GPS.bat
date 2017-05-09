@echo off
title "ARNPerf v6.1.090517"
set DIR=%cd%
set /p num="Enter GPS Module COM Number: 4 "
if "%num%" == "" set num=4
%DIR%\gps_win.pl com"%num%"
pause
