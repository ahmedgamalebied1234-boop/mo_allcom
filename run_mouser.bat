@echo off
setlocal enabledelayedexpansion

title Mouser All-Docs Harvest



rem ---- locate the scripts (pc_bundle\ subfolder, this folder, or a subfolder) ----

set "BASE=%~dp0"

set "SCRIPTDIR="

if exist "!BASE!pc_bundle\bridge_all.py" set "SCRIPTDIR=!BASE!pc_bundle"

if not defined SCRIPTDIR if exist "!BASE!bridge_all.py" set "SCRIPTDIR=!BASE!"

if not defined SCRIPTDIR (

    for /f "delims=" %%F in ('dir /b /s "!BASE!bridge_all.py" 2^>nul') do (

        if not defined SCRIPTDIR set "SCRIPTDIR=%%~dpF"

    )

)

if not defined SCRIPTDIR (

    echo [ERROR] bridge_all.py not found under !BASE!

    echo         Extract the whole zip and keep this .bat next to its folders.

    pause

    exit /b 1

)

cd /d "!SCRIPTDIR!"



rem ---- locate the input list ----

set "INPUT="

if exist "!BASE!input_lists\a4_5K_parts.xlsx" set "INPUT=!BASE!input_lists\a4_5K_parts.xlsx"

if not defined INPUT if exist "!BASE!a4_5K_parts.xlsx" set "INPUT=!BASE!a4_5K_parts.xlsx"

if not defined INPUT if exist "!SCRIPTDIR!\a4_5K_parts.xlsx" set "INPUT=!SCRIPTDIR!\a4_5K_parts.xlsx"

if not defined INPUT if exist "!SCRIPTDIR!\a4.xlsx" set "INPUT=!SCRIPTDIR!\a4.xlsx"

if not defined INPUT (

    for /f "delims=" %%F in ('dir /b /s "!BASE!a4*.xlsx" 2^>nul') do (

        if not defined INPUT set "INPUT=%%F"

    )

)

if not defined INPUT (

    echo [ERROR] Input list a4_5K_parts.xlsx not found under !BASE!

    pause

    exit /b 1

)



set "RPM=3"

set "WORKERS=1"

set "HB=60"



where python >nul 2>&1

if errorlevel 1 (

    echo [ERROR] Python not found in PATH. Install Python 3.9+ from python.org

    echo         and tick "Add Python to PATH" during setup.

    pause

    exit /b 1

)



:menu

cls

echo ==========================================

echo   Mouser All-Docs Harvest

echo ==========================================

echo   Scripts: !SCRIPTDIR!

echo   Input  : !INPUT!

echo   RPM    : %RPM%    Workers: %WORKERS%    Heartbeat: %HB%s (0=off)

echo ------------------------------------------

echo   1. Install dependencies (first time)

echo   2. Run offline self-test

echo   3. Quick test run (20 parts)

echo   4. FULL run (resumable - safe to stop/restart)

echo   5. Search-only mode (PCN rows only)

echo   6. Open output folder

echo   7. Diagnose connection (why nothing happens)

echo   8. Smart circuit breakers list (separate output)

echo   9. Watch it browse (visible Camoufox stealth-browser windows)

echo   0. Exit

echo ==========================================

set "CH="

set /p CH=Choose: 



if "%CH%"=="1" goto install

if "%CH%"=="2" goto selftest

if "%CH%"=="3" goto quick

if "%CH%"=="4" goto full

if "%CH%"=="5" goto search

if "%CH%"=="6" goto openout

if "%CH%"=="7" goto diag

if "%CH%"=="8" goto breakers

if "%CH%"=="9" goto visible

if "%CH%"=="0" exit /b 0

goto menu



:install

python -m pip install --upgrade pip

if exist requirements.txt (python -m pip install -r requirements.txt) else (python -m pip install requests)

python -m pip install openpyxl
python -m camoufox fetch

pause

goto menu



:selftest

python selftest_all.py

pause

goto menu



:quick

call :askworkers

call :askheartbeat

python -u bridge_all.py --file "!INPUT!" --mode all --rpm %RPM% --workers %WORKERS% --heartbeat %HB% --limit 20

pause

goto menu



:full

call :askworkers

call :askheartbeat

echo Ctrl+C to stop at any time; re-run option 4 to resume.

python -u bridge_all.py --file "!INPUT!" --mode all --rpm %RPM% --workers %WORKERS% --heartbeat %HB%

pause

goto menu



:search

call :askworkers

call :askheartbeat

python -u bridge_all.py --file "!INPUT!" --mode search --rpm %RPM% --workers %WORKERS% --heartbeat %HB%

pause

goto menu



:diag

python diag_probe.py

pause

goto menu





:visible

echo This opens visible Camoufox (stealth Firefox) windows so you can watch it browse.

echo Needs the camoufox package. First time here, choose 1 to install

echo dependencies (adds camoufox + the browser download).

echo Keep worker count low (2-4) - each one is a full browser window.

call :askworkers

call :askheartbeat

set "LOGIN="

set /p LOGIN=First time, or need to log in again? Opens Camoufox so you pass Mouser's slider once (y/N): 

if /i "!LOGIN!"=="y" python -u bridge_visible.py --setup-login --workers %WORKERS%

echo Your logins are kept in pc_bundle\camoufox_profile_N (permanent).

echo The browser will be opened and CLOSED again for every part.

python -u bridge_visible.py --file "!INPUT!" --mode all --rpm %RPM% --workers %WORKERS% --heartbeat %HB% --profile-mode persistent --bridge direct

pause

goto menu



:breakers

set "BLIST=!BASE!input_lists\smart_breakers.txt"

if not exist "!BLIST!" (

    echo [ERROR] !BLIST! not found.

    pause

    goto menu

)

set "HASPART="

for /f "usebackq eol=# tokens=*" %%L in ("!BLIST!") do set "HASPART=1"

if not defined HASPART (

    echo The smart-breaker list is empty.

    echo Add one part number per line in Notepad, save, then choose 8 again.

    start "" notepad "!BLIST!"

    pause

    goto menu

)

call :askworkers

call :askheartbeat

set "MM_REPO=!SCRIPTDIR!\mm_data_breakers"

set "MM_FINAL=!SCRIPTDIR!\final_breakers.csv"

python -u bridge_all.py --file "!BLIST!" --mode all --rpm %RPM% --workers %WORKERS% --heartbeat %HB%

set "MM_REPO="

set "MM_FINAL="

echo Results: !SCRIPTDIR!\final_breakers.csv

pause

goto menu



:openout

start "" explorer "!SCRIPTDIR!"

goto menu



:askworkers

set "W="

set /p W=How many workers? [default %WORKERS%, max 32]: 

if "%W%"=="" goto :eof

set "NONNUM="

for /f "delims=0123456789" %%a in ("%W%") do set "NONNUM=1"

if defined NONNUM (

    echo Not a number - keeping %WORKERS%

    goto :eof

)

if %W% LSS 1 (

    echo Must be at least 1 - keeping %WORKERS%

    goto :eof

)

if %W% GTR 32 (

    echo Too many - using 32

    set "W=32"

)

set "WORKERS=%W%"

goto :eof



:askheartbeat

set "H="

set /p H=Show heartbeat status line? Seconds between lines [default %HB%, 0 = off]: 

if "%H%"=="" goto :eof

set "NONNUM="

for /f "delims=0123456789" %%a in ("%H%") do set "NONNUM=1"

if defined NONNUM (

    echo Not a number - keeping %HB%

    goto :eof

)

set "HB=%H%"

goto :eof

