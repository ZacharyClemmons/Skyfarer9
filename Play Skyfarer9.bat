@echo off
rem Refresh Godot's import cache (new sprites and scripts), then start the game.
cd /d "%~dp0"
if not exist Skyfarer9.exe (
  echo Skyfarer9.exe not found. Copy Godot_v4.7-stable_win64.exe into this folder and rename it to Skyfarer9.exe.
  pause
  exit /b 1
)
echo Updating assets...
Skyfarer9.exe --headless --path . --import
start "" Skyfarer9.exe --path .
