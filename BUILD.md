# Сборка ECLIPSE VPN для Windows

## Требования

- Windows 10/11 (64-bit)
- Visual Studio 2022 с C++ workload
- Flutter SDK 3.16+
- sing-box v1.8.0+

## 1. Подготовка sing-box

Скачайте sing-box для Windows:
```powershell
# PowerShell
Invoke-WebRequest -Uri "https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-1.8.0-windows-amd64.zip" -OutFile "sing-box.zip"
Expand-Archive -Path "sing-box.zip" -DestinationPath "."
```

Поместите `sing-box.exe` в папку `windows/runner/Release/` рядом с `eclipse_vpn_windows.exe`.

## 2. Сборка приложения

```bash
# Установка зависимостей
flutter pub get

# Генерация кода (если используется retrofit/hive)
flutter pub run build_runner build --delete-conflicting-outputs

# Сборка релиза
flutter build windows --release
```

Готовый исполняемый файл будет в:
```
build/windows/x64/runner/Release/eclipse_vpn_windows.exe
```

## 3. Создание установщика (опционально)

Используйте Inno Setup для создания установщика:

```iss
; installer.iss
[Setup]
AppName=ECLIPSE VPN
AppVersion=0.1.0
DefaultDirName={pf}\ECLIPSE VPN
DefaultGroupName=ECLIPSE VPN
OutputDir=installer

[Files]
Source: "build\windows\x64\runner\Release\eclipse_vpn_windows.exe"; DestDir: "{app}"
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "sing-box\sing-box.exe"; DestDir: "{app}"

[Icons]
Name: "{group}\ECLIPSE VPN"; Filename: "{app}\eclipse_vpn_windows.exe"
Name: "{commondesktop}\ECLIPSE VPN"; Filename: "{app}\eclipse_vpn_windows.exe"
```

## 4. Настройка API

Перед сборкой укажите домен вашего бота в файле:
```
lib/core/api/api_client.dart
```

Замените:
```dart
static const String baseUrl = 'https://ваш-домен.com';
```

## 5. Развертывание

### Требования на целевой машине:
- Visual C++ Redistributable 2015-2022 x64
- Права администратора (для создания TUN-адаптера)

### Установка:
1. Запустите установщик или распакуйте portable-версию
2. При первом запуске Windows запросит права администратора — это необходимо для создания VPN-интерфейса
3. Введите код доступа из Telegram-бота

## Структура файлов после установки

```
ECLIPSE VPN/
├── eclipse_vpn_windows.exe    # Основное приложение
├── sing-box.exe               # VPN-ядро
├── flutter_windows.dll          # Flutter runtime
├── *.dll                      # Зависимости
└── data/                      # Данные приложения
    ├── app.so                 # Flutter код
    └── icudtl.dat             # ICU данные
```

## Отладка

Запуск с логами:
```powershell
.\eclipse_vpn_windows.exe --verbose
```

Логи sing-box сохраняются во временной папке:
```
%TEMP%\eclipse_vpn_config.json
```

## Примечания

- **TUN-адаптер**: sing-box использует wintun.dll для создания виртуального сетевого адаптера. При первом запуске может появиться запрос на установку драйвера.
- **Автозапуск**: Настраивается в настройках приложения (требует прав администратора).
- **Файрвол**: Windows Defender может запросить разрешение для sing-box.exe — разрешите доступ.

## Известные проблемы

1. **"sing-box.exe не найден"** — убедитесь, что sing-box.exe в той же папке, что и основное приложение
2. **Ошибка создания TUN** — запустите от имени администратора
3. **Антивирус блокирует** — добавьте папку приложения в исключения
