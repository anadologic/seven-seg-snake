@echo off
REM ============================================================================
REM program.bat - Program the Nexys A7 over JTAG with the built bitstream.
REM Run after build.bat has produced vivado\build\seven_seg_snake.bit.
REM ============================================================================
setlocal

set VIVADO=F:\Xilinx\Vivado\2023.1\bin\vivado.bat
set SCRIPT=%~dp0scripts\program.tcl

if not exist "%VIVADO%" (
    echo ERROR: Vivado not found at %VIVADO%
    exit /b 1
)
if not exist "%SCRIPT%" (
    echo ERROR: program script not found at %SCRIPT%
    exit /b 1
)

call "%VIVADO%" -mode batch -source "%SCRIPT%" -nojournal -nolog
exit /b %ERRORLEVEL%
