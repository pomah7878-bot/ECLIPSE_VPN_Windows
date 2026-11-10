# Сборка ECLIPSE VPN для Windows

## Требования

- Windows 10/11 (64-bit)
- Visual Studio 2022 или Build Tools с workload «Разработка классических приложений на C++»
- Flutter SDK 3.24+ (stable)
- sing-box 1.14.x (скачивается отдельно, см. ниже)
- wintun 0.14.1

## 1. Подготовка sing-box и wintun

```powershell
# PowerShell
Invoke-WebRequest -Uri "https://github.com/SagerNet/sing-box/releases/download/v1.14.4/sing-box-1.14.4-windows-amd64.zip" -OutFile "sing-box.zip"
Expand-Archive -Path "sing-box.zip" -DestinationPath "."

Invoke-WebRequest -Uri "https://www.wintun.net/builds/wintun-0.14.1.zip" -OutFile "wintun.zip"
Expand-Archive -Path "wintun.zip" -DestinationPath "."
```

Для запуска из IDE (`flutter run`) положите `sing-box.exe` и
`wintun\bin\amd64\wintun.dll` в корень проекта рядом с точкой запуска
(или в подпапку `sing-box/`). Приложение ищет их:

1. рядом с `eclipse_vpn_windows.exe`
2. в подпапке `sing-box/` рядом с exe
3. в текущей директории и её подпапке `sing-box/`

Для установщика CI кладёт их в `sing-box\sing-box.exe` и `wintun\wintun.dll`
(см. `.github/workflows/build.yml` и `installer.iss`).

## 2. Сборка приложения

```bash
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

Готовый исполняемый файл:
```
build/windows/x64/runner/Release/eclipse_vpn_windows.exe
```

## 3. Создание установщика

```powershell
# Inno Setup 6
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

Результат: `installer\ECLIPSE_VPN_Setup_<версия>.exe`

Установщик:
- требует права администратора (нужны для TUN-адаптера)
- кладёт sing-box.exe и wintun.dll рядом с приложением
- добавляет правила фаервола для приложения и sing-box
- проверяет наличие VC++ Redistributable 2015-2022 x64
- опции: ярлык на рабочем столе, автозапуск

## 4. Настройка API

Домен бота: `lib/core/api/api_client.dart` → `baseUrl`.

## 5. CI/CD (GitHub Actions)

`.github/workflows/build.yml`:
1. Flutter stable → `pub get` → `analyze --fatal-infos` → `test`
2. Скачивает sing-box 1.14.4 и wintun 0.14.1 (amd64)
3. `flutter build windows --release`
4. Собирает установщик Inno Setup
5. При пуше тега `v*` — публикует `.exe` в Releases

## Проверка конфига VPN вручную

Формат конфига sing-box 1.11+ отличается от старого (1.8).
Приложение валидирует конфиг командой `sing-box check` перед запуском.
Проверить вручную:

```powershell
.\sing-box.exe check -c "%APPDATA%\...\sing-box\config.json"
```

## Требования на целевой машине

- Windows 10/11 x64
- Visual C++ Redistributable 2015-2022 x64
- Права администратора (TUN-адаптер)
- При первом запуске sing-box скачает rule-set'ы (geoip-ru/geosite-ru) — нужен интернет

## Известные проблемы

1. **«sing-box.exe не найден»** — файлы должны лежать рядом с приложением
2. **«Нужны права администратора»** — перезапустите от имени администратора
3. **Антивирус блокирует** — добавьте папку приложения в исключения
4. **VPN не подключается** — откройте «Показать логи» на главном экране,
   приложите их к обращению в поддержку (вкладка «Поддержка»)
