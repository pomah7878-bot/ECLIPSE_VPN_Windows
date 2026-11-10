# ECLIPSE VPN для Windows

Нативный VPN-клиент на Flutter + sing-box.

## Особенности

- 🖥️ Нативное Windows-приложение (Flutter Desktop)
- 🔒 Поддержка VLESS/Reality, VMESS, Trojan, Hysteria2
- 📱 Интеграция с Telegram-ботом @EclipseVPNBot
- 🎨 Фирменный тёмный дизайн (как в Android-приложении)
- 📊 Реальная статистика трафика и пинга (счётчики TUN-адаптера)
- 🌐 Три режима маршрутизации: Умный / Белые списки / Как у всех
- 🔔 Иконка в трее: управление подключением, сворачивание окна
- 💳 Покупка и продление ключей в приложении (ЮKassa)
- 🔑 Сессия сохраняется между запусками (persistent cookies)
- 🔄 Автоимпорт конфигураций из API

## Архитектура

```
Flutter UI (Dart)
    ↓ HTTP API (cookie-сессия, X-Eclipse-App: 1)
ECLIPSE_VPN Bot (eclipse.unlimited.bot.nu)
    ↓
3x-ui/Xray Panel
```

```
Flutter App (Windows)
    ↓ Process API
sing-box.exe 1.14.x (TUN через wintun.dll)
```

## Быстрый старт

### Для пользователей

1. Скачайте установщик из [Releases](../../releases)
2. Запустите установку (потребуются права администратора)
3. Войдите кодом из Telegram-бота или через Google/Яндекс
4. Нажмите «Подключить»

### Для разработчиков

Требуется: Flutter SDK 3.24+, Visual Studio 2022/Build Tools (C++ workload).

```bash
git clone https://github.com/pomah7878-bot/ECLIPSE_VPN_Windows.git
cd ECLIPSE_VPN_Windows

flutter pub get
flutter analyze
flutter test

# sing-box.exe + wintun.dll должны лежать рядом с запускаемым exe
# (или в подпапке sing-box/ от текущей директории)
flutter run -d windows
```

Сборка релиза и установщика — см. [BUILD.md](BUILD.md).

## Настройка API

Домен бота задаётся в `lib/core/api/api_client.dart`:

```dart
static const String baseUrl = 'https://your-domain.com';
```

## Структура проекта

```
lib/
├── main.dart                  # Точка входа: окно, сервисы, сессия
├── core/
│   ├── api/                   # api_client, auth_api, keys_api, shop_api
│   ├── services/              # vpn_service, config_generator, oauth, tray, settings
│   └── theme/                 # Тёмная тема ECLIPSE
└── features/
    ├── auth/                  # Экран входа (код бота + OAuth PKCE)
    ├── shell/                 # Главная оболочка с навигацией
    ├── home/                  # Кнопка питания, статус, статистика
    ├── modes/                 # Режимы маршрутизации
    ├── purchase/              # Личный кабинет, тарифы, оплата
    ├── devices/               # Ключи и устройства
    └── support/               # Поддержка, логи, версия
```

## Ключевые зависимости

- **sing-box 1.14.x** — VPN-ядро (конфиг нового формата, rule-set'ы подгружаются удалённо, локальные geoip.db/geosite.db не нужны)
- **wintun 0.14.1** — драйвер TUN-адаптера
- **dio + cookie_jar** — HTTP с сохранением сессии между запусками
- **window_manager / tray_manager / launch_at_startup** — окно, трей, автозапуск

## CI/CD

GitHub Actions собирает установщик при создании тега `v*`
(перед сборкой выполняются `flutter analyze` и `flutter test`):

```bash
git tag v0.2.0
git push origin v0.2.0
```

Готовый `ECLIPSE_VPN_Setup_*.exe` появится в Releases.

## Лицензия

См. [LICENSE](LICENSE)

## Поддержка

- Telegram: @EclipseVPNBot
- Issues: [GitHub Issues](../../issues)
