@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
  echo Python Launcher 'py' not found. Install Python 3.11 or newer from python.org.
  echo Enable the Python launcher during installation.
  pause
  exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
  echo Creating a private Python virtual environment...
  py -3 -m venv .venv
  if errorlevel 1 (
    echo Python 3.11 or newer is required.
    pause
    exit /b 1
  )
  ".venv\Scripts\python.exe" -m pip install "z80-python>=0.4.0,<0.5.0"
  if errorlevel 1 (
    echo The Z80 core could not be installed. Check network access and retry.
    pause
    exit /b 1
  )
)
".venv\Scripts\python.exe" lex31_gui.py
if errorlevel 1 pause
