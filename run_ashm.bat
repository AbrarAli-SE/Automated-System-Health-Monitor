@echo off
:: =========================================
:: ASHM Live - Full Launcher
:: =========================================

:: Check if running as Administrator
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo This script must be run as Administrator!
    pause
    exit /b
)

:: Set your folder path here
set "ASHM_FOLDER=D:\5-Semester\ASHM-Live"

:: Go to folder
cd /d "%ASHM_FOLDER%"

:: Start server in a new PowerShell window
start powershell -NoProfile -ExecutionPolicy Bypass -Command ".\server.ps1"

:: Give server a few seconds to start
timeout /t 3 /nobreak >nul

:: Open the dashboard in default browser
start "" "%ASHM_FOLDER%\dashboard.html"

echo =========================================
echo ASHM Live server started and dashboard opened!
echo Keep the PowerShell window open to continue collecting data.
echo =========================================
pause
