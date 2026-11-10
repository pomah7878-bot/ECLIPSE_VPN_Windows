import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'config_generator.dart';

/// Пользовательские настройки (persistent).
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _keyRoutingMode = 'routing_mode';
  static const _keyAutostart = 'autostart_enabled';
  static const _keyDeviceId = 'device_id';

  SharedPreferences? _prefs;
  RoutingMode _routingMode = RoutingMode.smart;
  bool _autostart = false;
  String _deviceId = '';

  RoutingMode get routingMode => _routingMode;
  bool get autostartEnabled => _autostart;

  /// Стабильный идентификатор устройства (шлётся в X-HWID при запросе подписки).
  String get deviceId => _deviceId;

  /// Должен быть вызван один раз из main().
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _routingMode = RoutingModeX.fromId(_prefs?.getString(_keyRoutingMode));
    _autostart = _prefs?.getBool(_keyAutostart) ?? false;
    _deviceId = _prefs?.getString(_keyDeviceId) ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = _generateDeviceId();
      await _prefs?.setString(_keyDeviceId, _deviceId);
    }
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> setRoutingMode(RoutingMode mode) async {
    _routingMode = mode;
    await _prefs?.setString(_keyRoutingMode, mode.id);
  }

  Future<void> setAutostart(bool value) async {
    _autostart = value;
    await _prefs?.setBool(_keyAutostart, value);
  }
}
