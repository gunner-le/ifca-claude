@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
REM ============================================================
REM  Mo Claude Code cho IFCA: thu muc kien thuc + source client
REM  Cach dung:
REM    ifca.bat                      -> hien menu chon client
REM    ifca.bat LKHS_Train           -> mo thang 1 client
REM    ifca.bat LKHS_Train LKHS      -> mo nhieu thu muc (vd Train + Live de so sanh)
REM ============================================================
set "ROOT=E:\IFCA Software"
set "KB=%~dp0"

if not "%~1"=="" goto :args

echo.
echo  Chon source client (thu muc trong %ROOT%):
echo.
set i=0
for /d %%D in ("%ROOT%\*") do (
    set /a i+=1
    set "C!i!=%%~nxD"
    echo   !i!. %%~nxD
)
echo.
set /p N= Nhap so (vd 5) hoac 0 = chi mo kien thuc, khong source: 
if "%N%"=="0" (
    cd /d "%KB%"
    claude
    goto :eof
)
set "CLIENT=!C%N%!"
if "%CLIENT%"=="" (
    echo So khong hop le.
    pause
    goto :eof
)
cd /d "%KB%"
claude --add-dir "%ROOT%\%CLIENT%"
goto :eof

:args
set "DIRS="
:loop
if "%~1"=="" goto :run
set DIRS=!DIRS! --add-dir "%ROOT%\%~1"
shift
goto :loop
:run
cd /d "%KB%"
claude %DIRS%
