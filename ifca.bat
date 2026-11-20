@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM  Mo Claude Code cho IFCA: thu muc kien thuc + source client
REM    ifca.bat                  -> menu chon client
REM    ifca.bat LKHS_Train       -> mo thang 1 client
REM    ifca.bat LKHS_Train LKHS  -> mo nhieu thu muc
REM  Sau khi chon client: Enter = phien moi, 1 = tiep tuc phien gan nhat,
REM  2 = chon phien cu tu danh sach (lich su chat khong mat khi tat cmd)
REM ============================================================
set "ROOT=E:\IFCA Software"
set "KB=%~dp0"

REM --- Tim lenh claude: PATH, roi cac cho cai mac dinh ---
set "CLAUDE=claude"
where claude >nul 2>&1
if not errorlevel 1 goto :claudeok
set "CLAUDE="
if exist "%USERPROFILE%\.local\bin\claude.exe" set "CLAUDE=%USERPROFILE%\.local\bin\claude.exe"
if not defined CLAUDE if exist "%APPDATA%\npm\claude.cmd" set "CLAUDE=%APPDATA%\npm\claude.cmd"
if not defined CLAUDE if exist "%LOCALAPPDATA%\Programs\claude\claude.exe" set "CLAUDE=%LOCALAPPDATA%\Programs\claude\claude.exe"
REM ban di kem extension VS Code (lay ban moi nhat, duong dan doi theo version)
if not defined CLAUDE for /f "delims=" %%E in ('dir /b /ad /o:n "%USERPROFILE%\.vscode\extensions\anthropic.claude-code-*" 2^>nul') do (
    if exist "%USERPROFILE%\.vscode\extensions\%%E\resources\native-binary\claude.exe" set "CLAUDE=%USERPROFILE%\.vscode\extensions\%%E\resources\native-binary\claude.exe"
)
if not defined CLAUDE (
    echo.
    echo  [LOI] Khong tim thay Claude Code ^(claude^) tren may.
    echo  Da tim: PATH, %USERPROFILE%\.local\bin, %APPDATA%\npm, %LOCALAPPDATA%\Programs\claude
    echo  Chay lenh tim trong PowerShell ^(xem README^) roi sua dong set "CLAUDE=..." o tren.
    echo.
    pause
    goto :eof
)
:claudeok

if not exist "%ROOT%\" (
    echo  [LOI] Khong thay thu muc "%ROOT%". Sua dong set "ROOT=..." dau file.
    pause
    goto :eof
)

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
set "N="
echo   0. (khong source) - patch data / query tren server / chua clone source
echo.
set /p "N= Nhap so: "
if "%N%"=="0" (
    set "DIRS="
    goto :run
)
set "CLIENT=!C%N%!"
if "%CLIENT%"=="" (
    echo  [LOI] So khong hop le: %N%
    pause
    goto :eof
)
set DIRS=--add-dir "%ROOT%\%CLIENT%"
goto :run

:args
set "DIRS="
:loop
if "%~1"=="" goto :run
if not exist "%ROOT%\%~1\" (
    echo  [LOI] Khong thay thu muc "%ROOT%\%~1"
    pause
    goto :eof
)
set DIRS=!DIRS! --add-dir "%ROOT%\%~1"
shift
goto :loop

:run
REM --- Chon phien: moi / tiep tuc phien gan nhat / chon phien cu ---
echo.
echo  Phien lam viec:
echo   [Enter] Phien moi
echo   1. Tiep tuc phien gan nhat
echo   2. Chon phien cu de tiep tuc (danh sach)
echo.
set "M="
set "MODE="
set /p "M= Nhap so: "
if "%M%"=="1" set "MODE=--continue"
if "%M%"=="2" set "MODE=--resume"

cd /d "%KB%"
echo.
echo  Thu muc kien thuc: %KB%
echo  Lenh: "!CLAUDE!" !MODE! !DIRS!
echo.
call "!CLAUDE!" !MODE! !DIRS!
echo.
echo  Claude Code da thoat (ma loi %errorlevel%).
pause
