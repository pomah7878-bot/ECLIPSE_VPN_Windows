import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_service.dart';

/// Системные уведомления Windows о состоянии VPN.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _ready = false;

  Future<void> init() async {
    try {
      await localNotifier.setup(
        appName: 'ECLIPSE VPN',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> show(String title, String body) async {
    if (!_ready || !SettingsService().notificationsEnabled) return;
    try {
      final notification = LocalNotification(title: title, body: body);
      notification.onClick = () async {
        await windowManager.show();
        await windowManager.focus();
      };
      await notification.show();
    } catch (_) {
      // уведомление не критично для работы VPN
    }
  }
}
