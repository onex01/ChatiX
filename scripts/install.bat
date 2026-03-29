@echo off
setlocal

set URL=https://uploads.onex01.ru/Android/APKs/ChatiX/version.json

echo 📡 Getting latest version...

for /f "tokens=2 delims=:," %%a in ('curl -s %URL% ^| findstr version') do (
    set VERSION=%%~a
)

set VERSION=%VERSION:"=%

if "%VERSION%"=="" (
    echo ❌ Failed to get version
    exit /b 1
)

set APK_FILE=ChatiX-%VERSION%.apk
set APK_URL=https://uploads.onex01.ru/Android/APKs/ChatiX/%APK_FILE%

echo 📱 Downloading %APK_FILE%...
curl -o %APK_FILE% %APK_URL%

if errorlevel 1 (
    echo ❌ Download failed
    exit /b 1
)

echo 📱 Installing...
adb install -r %APK_FILE%

del %APK_FILE%

echo ✅ Done!