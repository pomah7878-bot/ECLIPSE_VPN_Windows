import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

enum AppThemeMode {
  system('Как в системе'),
  light('Светлая'),
  dark('Тёмная'),
  time('По времени суток');

  const AppThemeMode(this.title);
  final String title;
}

/// Тема Windows-клиента: системная, светлая, тёмная или по времени.
class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const _key = 'app_theme_mode';
  SharedPreferences? _prefs;
  AppThemeMode _mode = AppThemeMode.system;
  bool _dark = true;
  Timer? _timer;

  final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);

  AppThemeMode get mode => _mode;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    _mode = AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
    _apply(resolve());
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_mode != AppThemeMode.time) return;
      final next = resolve();
      if (next != _dark) _apply(next);
    });
  }

  bool resolve() {
    switch (_mode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.time:
        final hour = DateTime.now().hour;
        return hour < 7 || hour >= 21;
      case AppThemeMode.system:
        final brightness = PlatformDispatcher.instance.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    await _prefs?.setString(_key, mode.name);
    _apply(resolve());
  }

  void _apply(bool dark) {
    _dark = dark;
    AppTheme.apply(dark);
    isDark.value = dark;
  }

  void dispose() {
    _timer?.cancel();
  }
}
