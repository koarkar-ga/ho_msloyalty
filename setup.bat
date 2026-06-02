@echo off
SETLOCAL EnableDelayedExpansion

echo ==============================================
echo  MS Dashboard Production Setup (Windows)
echo ==============================================
echo.

:: Step 1: Check Node.js installation
echo Checking Node.js installation...
node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed.
    echo Please download and install Node.js from https://nodejs.org/
    echo Once installed, restart this terminal/folder and run setup.bat again.
    pause
    exit /b 1
)
echo [OK] Node.js is installed.
echo.

:: Step 2: Install local npm dependencies (express)
echo Installing local project dependencies...
call npm install --omit=dev
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install project dependencies.
    pause
    exit /b 1
)
echo [OK] Project dependencies installed successfully.
echo.

:: Step 3: Check/Install PM2 globally
echo Checking if PM2 is installed globally...
call pm2 -v >nul 2>&1
if %errorlevel% neq 0 (
    echo PM2 not found. Installing PM2 globally...
    call npm install -g pm2
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to install PM2 globally.
        echo Attempting to run via npx instead...
        set USE_NPX=true
    ) else (
        echo [OK] PM2 installed globally.
        set USE_NPX=false
    )
) else (
    echo [OK] PM2 is already installed.
    set USE_NPX=false
)
echo.

:: Step 4: Start application with PM2
echo Starting MS Dashboard with PM2...
if "%USE_NPX%"=="true" (
    call npx pm2 start ecosystem.config.js
) else (
    call pm2 start ecosystem.config.js
)

if %errorlevel% neq 0 (
    echo [ERROR] Failed to start application with PM2.
    pause
    exit /b 1
)

:: Step 5: Save PM2 list so it persists
if "%USE_NPX%"=="true" (
    call npx pm2 save
) else (
    call pm2 save
)
echo.

:: Step 6: Setup PM2 Windows Startup (so PM2 starts on boot)
echo Setting up PM2 to run on Windows Startup...
call npm install -g pm2-windows-startup
if %errorlevel% neq 0 (
    echo [WARNING] Failed to install pm2-windows-startup.
    echo Please configure PM2 startup manually or run: npm install -g pm2-windows-startup
) else (
    call pm2-startup install
    if !errorlevel! neq 0 (
        echo [WARNING] Failed to register PM2 startup.
    ) else (
        echo [OK] PM2 registered to autostart on Windows boot.
    )
)

echo.
echo ==============================================
echo  Setup Completed Successfully!
echo  Dashboard is running at: http://localhost
echo ==============================================
echo.
pause
