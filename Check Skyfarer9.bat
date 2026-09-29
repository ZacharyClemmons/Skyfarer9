@echo off
rem Generate a region, print a report and quit. A fast way to see whether a change broke
rem world generation without sitting through the game booting.
cd /d "%~dp0"
Skyfarer9_console.exe --headless --path . --quit-after 900 -- --gencheck %*
pause
