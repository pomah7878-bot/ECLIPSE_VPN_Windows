# ECLIPSE VPN для Windows

Кроссплатформенный VPN-клиент на Flutter + sing-box.

## Особенности

- 🖥️ Нативное Windows-приложение (Flutter Desktop)
- 🔒 Поддержка VLESS/Reality, Hysteria2
- 📱 Интеграция с Telegram-ботом ECLIPSE_VPN
- 🎨 Фирменный тёмный дизайн
- 📊 Статистика трафика в реальном времени
- 🔄 Автоимпорт конфигураций из API

## Архитектура

```
Flutter UI (Dart)
    ↓ HTTP API
ECLIPSE_VPN Bot (Python/aiohttp)
    ↓
3x-ui/Xray Panel
```

```
Flutter App (Windows)
    ↓ Process API
sing-box.exe (TUN/VPN)
```

## Быстрый старт

### Для пользователей

1. Скачайте последний релиз из [Releases](../../releases)
2. Установите или распакуйте portable-версию
3. Запустите ECLIPSE VPN (права администратора)
4. Введите код доступа из Telegram-бота
5. Выберите сервер и нажмите "Подключиться"

### Для разработчиков

```bash
# Клонирование
git clone https://github.com/pomah7878-bot/ECLIPSE_VPN_Windows.git
cd ECLIPSE_VPN_Windows

# Установка зависимостей
flutter pub get

# Запуск в debug-режиме
flutter run -d windows

# Сборка релиза
flutter build windows --release
```

## Настройка API

Укажите домен вашего бота в `lib/core/api/api_client.dart`:

```dart
static const String baseUrl = 'https://your-domain.com';
```

## Структура проекта

```
lib/
├── core/
│   ├── api/           # API клиенты (auth, keys, tariffs)
│   ├── models/        # Модели данных
│   ├── services/      # Сервисы (auth, storage)
│   └── theme/         # Тема приложения
├── features/
│   ├── auth/          # Авторизация
│   ├── home/          # Главный экран
│   ├── connection/    # VPN-подключение
│   │   ├── presentation/
│   │   └── services/  # sing-box интеграция
│   └── keys/          # Управление ключами
└── main.dart          # Точка входа
```

## Зависимости

- **Flutter** — UI фреймворк
- **sing-box** — VPN-ядро (Go)
- **dio** — HTTP клиент
- **window_manager** — управление окном
- **shared_preferences** — локальное хранение

## CI/CD

GitHub Actions автоматически собирает установщик при создании тега `v*`:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Готовый .exe будет в Releases.

## Лицензия

См. [LICENSE](LICENSE)

## Поддержка

- Telegram: @EclipseVPNBot
- Issues: [GitHub Issues](../../issues)
