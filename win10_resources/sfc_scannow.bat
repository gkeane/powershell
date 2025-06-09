@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem Windows 10 EOL Migration - System File Checker (SFC) Scan Script
rem Purpose: Performs SFC scan and logs results for Windows 10 systems
rem Requirements: 
rem   - PowerShell available
rem   - Write access to C:\ProgramData\Quest\KACE\user
rem   - Network access to \\chs-deploy\kacereport\sfc
rem ============================================================================

rem === SET TIMESTAMP & PATHS ===
rem Generate timestamp in format YYYYMMDD_HHMMSS using PowerShell
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "DT=%%t"

rem Define log file locations
set LOGDIR=C:\ProgramData\Quest\KACE\user
set LOG=%LOGDIR%\sfcscan.log
set SHARE=\\chs-deploy\kacereport\sfc
set DEST=%SHARE%\%COMPUTERNAME%_sfc_%DT%.log

rem === CHECK LOG AGE AND COOLDOWN PERIOD ===
rem If log exists, check if it's less than 30 days old to prevent excessive scanning
if exist "%LOG%" (
    rem Use PowerShell to calculate days since last scan
    for /f %%d in ('powershell -NoProfile -Command "(Get-Date) - (Get-Item \"%LOG%\").LastWriteTime | Select -ExpandProperty Days"') do set "FILEAGE=%%d"
    if !FILEAGE! LSS 30 (
        rem Log skip reason if scan was performed recently
        echo [INFO] Last scan was only !FILEAGE! days ago. Skipping. > "%LOG%"
        echo [INFO] Log file: %LOG% >> "%LOG%"
        goto :end
    )
)

rem === EXECUTE SFC SCAN ===
rem Create new log file with system information
echo ==== SFC Log from %COMPUTERNAME% on %DATE% %TIME% ==== > "%LOG%"
echo [INFO] Bitness: %PROCESSOR_ARCHITECTURE% >> "%LOG%"

rem Handle different system architectures
if /i "%PROCESSOR_ARCHITECTURE%"=="x86" (
    rem For 32-bit systems, use SysNative to access 64-bit PowerShell
    echo [INFO] Launching 64-bit SFC via PowerShell... >> "%LOG%"
    "%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "sfc /scannow" >> "%LOG%" 2>&1
) else (
    rem For 64-bit systems, use native PowerShell
    echo [INFO] Running native SFC via PowerShell... >> "%LOG%"
    powershell -NoProfile -Command "sfc /scannow" >> "%LOG%" 2>&1
)

rem === COPY LOG TO NETWORK SHARE ===
rem Attempt to copy log to network share and handle any errors
echo [INFO] Copying log to %DEST% >> "%LOG%"
copy "%LOG%" "%DEST%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy log to %DEST% >> "%LOG%"
) else (
    echo [SUCCESS] Log successfully copied to %DEST% >> "%LOG%"
)

:end
rem Log script completion
echo [DONE] Script complete at %DATE% %TIME% >> "%LOG%"
endlocal
