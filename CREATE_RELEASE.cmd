@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lib\CreateRelease.ps1"
if errorlevel 1 echo Failed to create release ZIP. Review the message above.
pause
