@echo off
setlocal
cd /d "%~dp0"

where go >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Go is not installed or is not available in PATH.
    echo Download Go from the official website, install it, and run this file again.
    pause
    exit /b 1
)

set GOOS=windows
set GOARCH=amd64
set CGO_ENABLED=0

echo Building BrokenAppsCleaner.exe...
go build -trimpath -ldflags="-s -w -H=windowsgui" -o BrokenAppsCleaner.exe .
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

echo.
echo Build completed: %CD%\BrokenAppsCleaner.exe
pause
