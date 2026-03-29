@echo off
setlocal

set PROJECT_DIR=C:\ChatiX\ChatiX
set BACKUP_DIR=%PROJECT_DIR%\.backup

cd /d %PROJECT_DIR%

if exist "%BACKUP_DIR%\pubspec.yaml.backup" (
    echo 🔄 Rolling back...

    copy "%BACKUP_DIR%\pubspec.yaml.backup" pubspec.yaml >nul

    if exist "%BACKUP_DIR%\version.dart.backup" (
        copy "%BACKUP_DIR%\version.dart.backup" lib\version.dart >nul
    )

    rmdir /s /q "%BACKUP_DIR%"

    for /f "tokens=2 delims=:" %%a in ('findstr "version:" pubspec.yaml') do (
        set VERSION=%%a
    )

    set VERSION=%VERSION: =%

    echo ✅ Rolled back to %VERSION%
) else (
    echo ❌ No backup found!
)