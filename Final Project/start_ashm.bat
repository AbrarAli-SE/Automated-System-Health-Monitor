@echo off
title ASHM - Automated System Health Monitor
color 0B

echo ================================================
echo   ASHM - Automated System Health Monitor
echo   Professional System Diagnostic Platform
echo ================================================
echo.
echo [INITIALIZING SYSTEM...]
echo.

cd /d "%~dp0"

echo [1/2] Starting Live Data Server...
start "ASHM_SERVER" /MIN powershell.exe -NoProfile -ExecutionPolicy Bypass -File "ASHM\server.ps1"

timeout /t 3 /nobreak >nul

echo [2/2] Opening Main Dashboard...
start "" "http://localhost:8000"

echo.
echo ================================================
echo   SYSTEM READY!
echo   Dashboard: http://localhost:8000
echo   Keep this window open while using ASHM
echo ================================================
echo.
echo Press any key to STOP the server and exit...
pause >nul

taskkill /FI "WindowTitle eq ASHM_SERVER*" /F >nul 2>&1
echo.
echo ASHM Stopped. Goodbye!
timeout /t 2 /nobreak >nul