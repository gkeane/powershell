@echo off
setlocal enabledelayedexpansion

rem === SET TIMESTAMP & PATHS ===
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "DT=%%t"
set LOGDIR=C:\ProgramData\Quest\KACE\user
set LOG=%LOGDIR%\sfcscan.log
set SHARE=\\chs-deploy\kacereport\sfc
set DEST=%SHARE%\%COMPUTERNAME%_sfc_%DT%.log

rem === IF LOG EXISTS, CHECK AGE ===
if exist "%LOG%" (
    for /f %%d in ('powershell -NoProfile -Command "(Get-Date) - (Get-Item \"%LOG%\").LastWriteTime | Select -ExpandProperty Days"') do set "FILEAGE=%%d"
    if !FILEAGE! LSS 30 (
        echo [INFO] Last scan was only !FILEAGE! days ago. Skipping. > "%LOG%"
        echo [INFO] Log file: %LOG% >> "%LOG%"
        goto :end
    )
)

rem === RUN SFC IF NO LOG OR LOG IS 30+ DAYS OLD ===
echo ==== SFC Log from %COMPUTERNAME% on %DATE% %TIME% ==== > "%LOG%"
echo [INFO] Bitness: %PROCESSOR_ARCHITECTURE% >> "%LOG%"

if /i "%PROCESSOR_ARCHITECTURE%"=="x86" (
    echo [INFO] Launching 64-bit SFC via PowerShell... >> "%LOG%"
    "%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "sfc /scannow" >> "%LOG%" 2>&1
) else (
    echo [INFO] Running native SFC via PowerShell... >> "%LOG%"
    powershell -NoProfile -Command "sfc /scannow" >> "%LOG%" 2>&1
)

rem === COPY LOG TO NETWORK SHARE ===
echo [INFO] Copying log to %DEST% >> "%LOG%"
copy "%LOG%" "%DEST%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy log to %DEST% >> "%LOG%"
) else (
    echo [SUCCESS] Log successfully copied to %DEST% >> "%LOG%"
)

:end
echo [DONE] Script complete at %DATE% %TIME% >> "%LOG%"
endlocal
