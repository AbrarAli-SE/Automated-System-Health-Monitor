@echo off
ECHO Running Automated System Health Monitor...

:: This command launches the PowerShell script silently, bypassing execution policies for the current session.
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows_health_monitor.ps1"

ECHO.
ECHO COMPLETE! A new HTML report has been generated in this folder.
ECHO Press any key to close this window...
pause > NUL