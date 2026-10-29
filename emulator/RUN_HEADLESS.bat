@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Run START_EMULATOR.bat first to install the Z80 core.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" lex31_gui.py --headless --steps 150000 --trace
pause
