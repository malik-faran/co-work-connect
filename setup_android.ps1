# Android Toolchain Setup Script
# Run this in PowerShell as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Toolchain Auto Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Flutter
Write-Host "Step 1: Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version
    Write-Host "Flutter found!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Flutter not found!" -ForegroundColor Red
    Write-Host "Please install Flutter first: https://flutter.dev/docs/get-started/install"
    exit 1
}
Write-Host ""

# Step 2: Check current status
Write-Host "Step 2: Checking current status..." -ForegroundColor Yellow
flutter doctor
Write-Host ""

# Step 3: Set Android SDK location
Write-Host "Step 3: Setting up Android SDK..." -ForegroundColor Yellow
$androidHome = "$env:LOCALAPPDATA\Android\Sdk"

if (-not (Test-Path $androidHome)) {
    Write-Host "Creating Android SDK directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $androidHome -Force | Out-Null
}

Write-Host "Android SDK Home: $androidHome" -ForegroundColor Green
Write-Host ""

# Step 4: Check if Chocolatey is installed
Write-Host "Step 4: Checking for Chocolatey..." -ForegroundColor Yellow
$chocoInstalled = $false
try {
    $null = choco --version
    $chocoInstalled = $true
    Write-Host "Chocolatey found!" -ForegroundColor Green
} catch {
    Write-Host "Chocolatey not found. Installing..." -ForegroundColor Yellow
    
    # Install Chocolatey
    Write-Host "Installing Chocolatey (requires Administrator)..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    if ($LASTEXITCODE -eq 0) {
        $chocoInstalled = $true
        Write-Host "Chocolatey installed successfully!" -ForegroundColor Green
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
}
Write-Host ""

# Step 5: Install Android SDK via Chocolatey or manual
if ($chocoInstalled) {
    Write-Host "Step 5: Installing Android SDK via Chocolatey..." -ForegroundColor Yellow
    choco install android-sdk -y
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Chocolatey installation had issues. Trying manual setup..." -ForegroundColor Yellow
        $chocoInstalled = $false
    }
}

# Step 6: Set Environment Variables
Write-Host "Step 6: Setting environment variables..." -ForegroundColor Yellow

# Set ANDROID_HOME for current session
$env:ANDROID_HOME = $androidHome

# Set ANDROID_HOME permanently (requires Admin)
try {
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "Machine")
    Write-Host "ANDROID_HOME set to: $androidHome" -ForegroundColor Green
} catch {
    Write-Host "Could not set ANDROID_HOME system-wide (requires Admin). Setting for user..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidHome, "User")
}

# Add to PATH
$pathsToAdd = @(
    "$androidHome\platform-tools",
    "$androidHome\tools",
    "$androidHome\cmdline-tools\bin"
)

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($path in $pathsToAdd) {
    if ($currentPath -notlike "*$path*") {
        $currentPath += ";$path"
        Write-Host "Adding to PATH: $path" -ForegroundColor Yellow
    }
}

try {
    [Environment]::SetEnvironmentVariable("Path", $currentPath, "User")
    Write-Host "PATH updated!" -ForegroundColor Green
} catch {
    Write-Host "Could not update PATH automatically. Please add manually:" -ForegroundColor Yellow
    foreach ($path in $pathsToAdd) {
        Write-Host "  $path" -ForegroundColor Cyan
    }
}
Write-Host ""

# Step 7: Download and setup Command Line Tools if not present
Write-Host "Step 7: Setting up Android Command Line Tools..." -ForegroundColor Yellow

$cmdlineToolsPath = "$androidHome\cmdline-tools\bin"
if (-not (Test-Path "$cmdlineToolsPath\sdkmanager.bat")) {
    Write-Host "Command Line Tools not found. Downloading..." -ForegroundColor Yellow
    
    $toolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip"
    $toolsZip = "$env:TEMP\android-cmdline-tools.zip"
    $toolsExtract = "$env:TEMP\android-cmdline-tools"
    
    Write-Host "Downloading from: $toolsUrl" -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $toolsUrl -OutFile $toolsZip -UseBasicParsing
        Write-Host "Download complete!" -ForegroundColor Green
        
        Write-Host "Extracting..." -ForegroundColor Yellow
        Expand-Archive -Path $toolsZip -DestinationPath $toolsExtract -Force
        
        # Move to correct location
        if (Test-Path "$toolsExtract\cmdline-tools") {
            if (-not (Test-Path "$androidHome\cmdline-tools")) {
                New-Item -ItemType Directory -Path "$androidHome\cmdline-tools" -Force | Out-Null
            }
            Copy-Item "$toolsExtract\cmdline-tools\*" -Destination "$androidHome\cmdline-tools\" -Recurse -Force
            Write-Host "Command Line Tools installed!" -ForegroundColor Green
        }
        
        # Cleanup
        Remove-Item $toolsZip -Force -ErrorAction SilentlyContinue
        Remove-Item $toolsExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Automatic download failed. Please download manually:" -ForegroundColor Red
        Write-Host "https://developer.android.com/studio#command-tools" -ForegroundColor Cyan
    }
} else {
    Write-Host "Command Line Tools already installed!" -ForegroundColor Green
}
Write-Host ""

# Step 8: Install required Android packages
Write-Host "Step 8: Installing required Android packages..." -ForegroundColor Yellow

if (Test-Path "$cmdlineToolsPath\sdkmanager.bat") {
    Write-Host "Installing platform-tools, Android 33, and build-tools..." -ForegroundColor Yellow
    
    & "$cmdlineToolsPath\sdkmanager.bat" "platform-tools" "platforms;android-33" "build-tools;33.0.0"
    
    Write-Host ""
    Write-Host "Accepting Android licenses..." -ForegroundColor Yellow
    echo y | & "$cmdlineToolsPath\sdkmanager.bat" --licenses
    
    Write-Host "Packages installed!" -ForegroundColor Green
} else {
    Write-Host "SDK Manager not found. Please install Command Line Tools first." -ForegroundColor Red
}
Write-Host ""

# Step 9: Update local.properties
Write-Host "Step 9: Updating local.properties..." -ForegroundColor Yellow

$projectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$localPropertiesPath = Join-Path $projectPath "android\local.properties"

if (Test-Path $localPropertiesPath) {
    $content = Get-Content $localPropertiesPath
} else {
    $content = @()
}

# Get Flutter SDK path
$flutterPath = (Get-Command flutter).Source
$flutterSdk = Split-Path -Parent (Split-Path -Parent $flutterPath)

# Update or create local.properties
$newContent = @()
$sdkDirSet = $false
$flutterSdkSet = $false

foreach ($line in $content) {
    if ($line -match "^sdk\.dir=") {
        $newContent += "sdk.dir=$androidHome"
        $sdkDirSet = $true
    } elseif ($line -match "^flutter\.sdk=") {
        $newContent += "flutter.sdk=$flutterSdk"
        $flutterSdkSet = $true
    } else {
        $newContent += $line
    }
}

if (-not $sdkDirSet) {
    $newContent += "sdk.dir=$androidHome"
}
if (-not $flutterSdkSet) {
    $newContent += "flutter.sdk=$flutterSdk"
}

$newContent | Set-Content $localPropertiesPath
Write-Host "local.properties updated!" -ForegroundColor Green
Write-Host ""

# Step 10: Final check
Write-Host "Step 10: Running final Flutter doctor check..." -ForegroundColor Yellow
Write-Host ""

# Refresh environment variables
$env:ANDROID_HOME = $androidHome
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

flutter doctor

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If Android toolchain still shows issues:" -ForegroundColor Yellow
Write-Host "1. Restart VS Code/Command Prompt" -ForegroundColor White
Write-Host "2. Run: flutter doctor --android-licenses" -ForegroundColor White
Write-Host "3. Verify ANDROID_HOME is set: echo `$env:ANDROID_HOME" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")









