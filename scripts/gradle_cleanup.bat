@echo off
echo === Gradle lock cleanup ===
cd /d "%~dp0..\android"

call gradlew.bat --stop >nul 2>&1
timeout /t 2 /nobreak >nul

if exist ".gradle\noVersion" (
  rmdir /s /q ".gradle\noVersion"
  echo Removed buildLogic lock folder
)

for /f "tokens=2" %%p in ('tasklist /fi "imagename eq java.exe" /fo list 2^>nul ^| findstr /i "PID:"') do (
  echo Stopping java.exe PID %%p
  taskkill /F /PID %%p >nul 2>&1
)

echo.
echo Done. Wait 5 seconds, then run ONLY:
echo   cd C:\FYP\cwc
echo   flutter run
echo.
echo Do NOT run gradlew and flutter run at the same time.
timeout /t 5 /nobreak >nul
