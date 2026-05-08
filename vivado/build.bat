@echo off
REM ============================================================================
REM build.bat - Build a Vivado project + bitstream for seven-seg-snake.
REM Run from the repo root or from anywhere; paths in build.tcl are absolute.
REM ============================================================================
setlocal

set VIVADO=F:\Xilinx\Vivado\2023.1\bin\vivado.bat
set SCRIPT=%~dp0scripts\build.tcl

if not exist "%VIVADO%" (
    echo ERROR: Vivado not found at %VIVADO%
    exit /b 1
)
if not exist "%SCRIPT%" (
    echo ERROR: build script not found at %SCRIPT%
    exit /b 1
)

call "%VIVADO%" -mode batch -source "%SCRIPT%" -nojournal -nolog
exit /b %ERRORLEVEL%
