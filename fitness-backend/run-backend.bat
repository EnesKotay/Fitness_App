@echo off
REM Backend baslatma: 8080 portunu kullanan islemi kapatir, sonra Quarkus baslatir.
REM Cift tikla veya: run-backend.bat

set PORT=8080
for /f "tokens=5" %%a in ('netstat -a -n -o ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
  echo Port %PORT% kullanan islem kapatiliyor: PID %%a
  taskkill /PID %%a /F >nul 2>&1
  timeout /t 1 /nobreak >nul
)

cd /d "%~dp0"
call mvnw.cmd quarkus:dev -DskipTests
