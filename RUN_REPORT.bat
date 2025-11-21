@echo off
ECHO Running Automated System Health Monitor (ASHM)...

:: Checks if the PowerShell script exists in the same directory
IF NOT EXIST "windows_health_monitor.ps1" (
ECHO ERROR: The PowerShell script 'windows_health_monitor.ps1' was not found.
PAUSE
EXIT /B 1
)

:: Execute the PowerShell script.
:: -ExecutionPolicy Bypass: Temporarily bypasses execution policy for the script.
:: -File: Specifies the script to run.
:: -NoProfile: Prevents loading the current user profile, speeding up execution.
:: -WindowStyle Hidden: Runs the PowerShell window silently. Change to -WindowStyle Normal if you want to see the progress.
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "windows_health_monitor.ps1"

ECHO.
ECHO ASHM report generation complete. The HTML file should open automatically.
PAUSE