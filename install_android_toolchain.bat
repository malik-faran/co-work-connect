@echo off
echo ========================================
echo Android Toolchain Setup - Auto Install
echo ========================================
echo.

echo Step 1: Checking Flutter installation...
flutter --version
if errorlevel 1 (
    echo ERROR: Flutter not found in PATH!
    echo Please install Flutter first.
    pause
    exit /b 1
)
echo.

echo Step 2: Checking current status...
flutter doctor
echo.

echo Step 3: Setting up Android SDK directory...
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
if not exist "%ANDROID_HOME%" (
    echo Creating Android SDK directory...
    mkdir "%ANDROID_HOME%"
)
echo Android SDK Home: %ANDROID_HOME%
echo.

echo Step 4: Downloading Android Command Line Tools...
echo Please download from: https://developer.android.com/studio#command-tools
echo Or we'll use chocolatey if available...
echo.

echo Step 5: Checking for Chocolatey...
choco --version >nul 2>&1
if errorlevel 1 (
    echo Chocolatey not found. Installing...
    echo Please run PowerShell as Administrator and run:
    echo Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    echo.
    echo After installing Chocolatey, run this script again.
    pause
    exit /b 1
) else (
    echo Chocolatey found!
    echo.
    echo Step 6: Installing Android SDK Command Line Tools via Chocolatey...
    choco install android-sdk -y
    if errorlevel 1 (
        echo Chocolatey installation failed. Using manual method...
        goto :manual_setup
    )
)

echo.
echo Step 7: Setting up environment variables...
setx ANDROID_HOME "%ANDROID_HOME%" /M
if errorlevel 1 (
    echo Note: Setting ANDROID_HOME requires Administrator privileges.
    echo Setting for current user only...
    setx ANDROID_HOME "%ANDROID_HOME%"
)

echo.
echo Step 8: Updating PATH...
echo Adding Android SDK to PATH...
echo Please add these to your PATH manually if needed:
echo %ANDROID_HOME%\platform-tools
echo %ANDROID_HOME%\tools
echo %ANDROID_HOME%\cmdline-tools\bin
echo.

echo Step 9: Installing required Android packages...
if exist "%ANDROID_HOME%\cmdline-tools\bin\sdkmanager.bat" (
    echo Installing Android SDK packages...
    "%ANDROID_HOME%\cmdline-tools\bin\sdkmanager.bat" "platform-tools" "platforms;android-33" "build-tools;33.0.0"
    
    echo.
    echo Accepting Android licenses...
    "%ANDROID_HOME%\cmdline-tools\bin\sdkmanager.bat" --licenses
) else (
    echo SDK Manager not found. Please install Android Command Line Tools manually.
    goto :manual_setup
)

echo.
echo Step 10: Creating local.properties file...
cd cwc\android
echo flutter.sdk=%FLUTTER_SDK%> local.properties
echo sdk.dir=%ANDROID_HOME%>> local.properties
cd ..\..

echo.
echo Step 11: Final check...
flutter doctor

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo If Android toolchain still shows issues:
echo 1. Restart VS Code/Command Prompt
echo 2. Run: flutter doctor --android-licenses
echo 3. Verify ANDROID_HOME is set correctly
echo.
pause
exit /b 0

:manual_setup
echo.
echo ========================================
echo Manual Setup Required
echo ========================================
echo.
echo Please follow these steps:
echo.
echo 1. Download Android Command Line Tools:
echo    https://developer.android.com/studio#command-tools
echo.
echo 2. Extract to: %ANDROID_HOME%\cmdline-tools
echo.
echo 3. Set environment variable:
echo    ANDROID_HOME = %ANDROID_HOME%
echo.
echo 4. Add to PATH:
echo    %%ANDROID_HOME%%\platform-tools
echo    %%ANDROID_HOME%%\tools
echo    %%ANDROID_HOME%%\cmdline-tools\bin
echo.
echo 5. Install packages:
echo    sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.0"
echo.
echo 6. Accept licenses:
echo    sdkmanager --licenses
echo.
pause
exit /b 1









