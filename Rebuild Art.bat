@echo off
rem Regenerate every sprite sheet from tools/artgen, then re-import so the game picks them
rem up. Run this after editing anything in tools/artgen. Needs Python with numpy + Pillow.
cd /d "%~dp0"
echo Generating sprite sheets...
python tools\artgen\gen.py %*
if errorlevel 1 (
  echo.
  echo Art generation failed. Is Python on PATH with numpy and Pillow installed?
  pause
  exit /b 1
)
echo Re-importing into Godot...
Skyfarer9.exe --headless --path . --import
echo.
echo Done. Sheets rebuilt and imported.
pause
