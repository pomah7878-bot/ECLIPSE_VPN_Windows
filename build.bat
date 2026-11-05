@echo off
chcp 65001 >nul
title Сборка ECLIPSE VPN для Windows

echo ========================================
echo   ECLIPSE VPN - Сборка установщика
echo ========================================
echo.

:: Проверка Flutter
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ОШИБКА] Flutter не найден в PATH
    echo Установите Flutter: https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

:: Проверка sing-box
if not exist "sing-box\sing-box.exe" (
    echo [ПРЕДУПРЕЖДЕНИЕ] sing-box.exe не найден
    echo Скачайте: https://github.com/SagerNet/sing-box/releases
    echo и поместите в папку sing-box\
    echo.
    set /p CONTINUE="Продолжить без sing-box? (y/n): "
    if /i not "%CONTINUE%"=="y" exit /b 1
)

echo [1/4] Очистка старых сборок...
if exist "build\windows" rmdir /s /q "build\windows"
if exist "installer" rmdir /s /q "installer"

echo [2/4] Установка зависимостей...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ОШИБКА] Не удалось установить зависимости
    pause
    exit /b 1
)

echo [3/4] Сборка приложения...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ОШИБКА] Сборка не удалась
    pause
    exit /b 1
)

echo [4/4] Создание установщика...
where iscc >nul 2>nul
if %errorlevel% equ 0 (
    iscc installer.iss
    if %errorlevel% equ 0 (
        echo.
        echo ========================================
        echo   ГОТОВО!
        echo ========================================
        echo Установщик: installer\ECLIPSE_VPN_Setup_0.1.0.exe
    ) else (
        echo [ОШИБКА] Не удалось создать установщик
    )
) else (
    echo [ПРЕДУПРЕЖДЕНИЕ] Inno Setup не найден
    echo Скачайте: https://jrsoftware.org/isdl.php
    echo.
    echo Приложение собрано в: build\windows\x64\runner\Release\
)

echo.
pause
