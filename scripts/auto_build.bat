@echo off
setlocal enabledelayedexpansion

REM ===== COLORS (частично работают в новых терминалах) =====
echo.

REM ===== CONFIG =====
set SERVER_USER=root
set SERVER_PASS=dfkj04251
set SERVER_HOST=onex01.ru
set SERVER_PORT=22
set SERVER_PATH=/var/www/rizz
set UPLOAD_URL=https://rizz.onex01.ru/
set PROJECT_DIR=C:\Rizz\Rizz
set BACKUP_DIR=%PROJECT_DIR%\.backup

cd /d %PROJECT_DIR%

echo  Starting build process...
echo  Server: %SERVER_HOST%

REM ===== BACKUP =====
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

for /f "tokens=2 delims=:" %%a in ('findstr "version:" pubspec.yaml') do (
    set CURRENT_VERSION=%%a
)

set CURRENT_VERSION=%CURRENT_VERSION: =%
echo  Current version: %CURRENT_VERSION%

REM ===== PARSE VERSION =====
for /f "tokens=1,2 delims=+" %%a in ("%CURRENT_VERSION%") do (
    set VERSION_NUMBER=%%a
    set BUILD_NUMBER=%%b
)

for /f "tokens=1,2,3 delims=." %%a in ("%VERSION_NUMBER%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set PATCH=%%c
)

set /a NEW_PATCH=PATCH+1
set /a NEW_BUILD_NUMBER=BUILD_NUMBER+1

set NEW_VERSION_NUMBER=%MAJOR%.%MINOR%.%NEW_PATCH%
set NEW_VERSION=%NEW_VERSION_NUMBER%+%NEW_BUILD_NUMBER%

echo  Next version: %NEW_VERSION%

REM ===== BACKUP FILES =====
copy pubspec.yaml "%BACKUP_DIR%\pubspec.yaml.backup" >nul

if exist lib\version.dart (
    copy lib\version.dart "%BACKUP_DIR%\version.dart.backup" >nul
)

REM ===== UPDATE pubspec.yaml =====
powershell -Command "(Get-Content pubspec.yaml) -replace '%CURRENT_VERSION%', '%NEW_VERSION%' | Set-Content pubspec.yaml"

REM ===== WRITE version.dart =====
(
echo // Auto-generated version file
echo class AppVersion {
echo   static const String version = '%NEW_VERSION_NUMBER%';
echo   static const int buildNumber = %NEW_BUILD_NUMBER%;
echo   static const String fullVersion = '%NEW_VERSION%';
echo }
) > lib\version.dart

REM ===== BUILD =====
echo Building APK...
call flutter clean
call flutter pub get
call flutter build apk --release

if errorlevel 1 (
    echo Build failed! Rolling back...

    copy "%BACKUP_DIR%\pubspec.yaml.backup" pubspec.yaml >nul

    if exist "%BACKUP_DIR%\version.dart.backup" (
        copy "%BACKUP_DIR%\version.dart.backup" lib\version.dart >nul
    )

    rmdir /s /q "%BACKUP_DIR%"
    exit /b 1
)

echo  Build successful!

REM ===== APK =====
set APK_NAME=Rizz-%NEW_VERSION_NUMBER%.apk

copy build\app\outputs\flutter-apk\app-release.apk build\app\outputs\flutter-apk\%APK_NAME%

for %%A in (build\app\outputs\flutter-apk\%APK_NAME%) do set FILE_SIZE=%%~zA

REM ===== version.json =====
(
echo {
echo   "version": "%NEW_VERSION_NUMBER%",
echo   "buildNumber": %NEW_BUILD_NUMBER%,
echo   "downloadUrl": "%UPLOAD_URL%/%APK_NAME%",
echo   "fileSize": %FILE_SIZE%
echo   "changelog": "• Исправлены ошибки\n• Улучшена производительность\n• Добавлена поддержка фоновых обновлений",
echo }
) > build\app\outputs\flutter-apk\version.json

REM ===== SFTP SCRIPT =====
set SFTP_SCRIPT=%TEMP%\sftp_commands.txt

(
echo mkdir %SERVER_PATH%
echo cd %SERVER_PATH%
echo put build/app/outputs/flutter-apk/%APK_NAME%
echo put build/app/outputs/flutter-apk/version.json
echo bye
) > "%SFTP_SCRIPT%"

echo  Uploading via SFTP...

REM ===== PASSWORD (через PowerShell hack) =====
powershell -Command ^
"$p='%SERVER_PASS%';" ^
"$cmd='sftp -P %SERVER_PORT% %SERVER_USER%@%SERVER_HOST% -b %SFTP_SCRIPT%';" ^
"$sec=ConvertTo-SecureString $p -AsPlainText -Force;" ^
"$cred=New-Object System.Management.Automation.PSCredential('%SERVER_USER%',$sec);" ^
"Start-Process cmd -ArgumentList '/c ' + $cmd -Credential $cred -Wait"

echo  Upload complete

REM ===== CLEANUP =====
del "%SFTP_SCRIPT%"
rmdir /s /q "%BACKUP_DIR%"

echo.
echo ==========================================
echo  BUILD AND UPLOAD COMPLETE
echo ==========================================
echo  %UPLOAD_URL%/%APK_NAME%
echo  %UPLOAD_URL%/version.json
echo ==========================================