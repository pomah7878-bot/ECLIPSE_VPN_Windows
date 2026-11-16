import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN-блокировка приложения: код хранится только как SHA-256.
class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  static const _enabledKey = 'app_lock_enabled';
  static const _pinKey = 'app_lock_pin_hash';

  SharedPreferences? _prefs;
  bool _enabled = false;
  String? _pinHash;

  bool get enabled => _enabled;
  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;

  /// Глобальное состояние: приложение заблокировано (для оверлея).
  final ValueNotifier<bool> locked = ValueNotifier<bool>(false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_enabledKey) ?? false;
    _pinHash = _prefs?.getString(_pinKey);
    locked.value = _enabled && hasPin;
  }

  Future<bool> setPin(String pin) async {
    if (pin.length < 4 || pin.length > 8 || int.tryParse(pin) == null) return false;
    _pinHash = sha256.convert(utf8.encode(pin)).toString();
    await _prefs?.setString(_pinKey, _pinHash!);
    await _prefs?.setBool(_enabledKey, true);
    _enabled = true;
    locked.value = false;
    return true;
  }

  Future<void> setEnabled(bool value) async {
    if (value && !hasPin) return;
    _enabled = value;
    await _prefs?.setBool(_enabledKey, value);
    locked.value = value && hasPin;
  }

  Future<void> disable() async {
    _enabled = false;
    await _prefs?.setBool(_enabledKey, false);
    locked.value = false;
  }

  Future<bool> verify(String pin) async {
    if (!hasPin) return true;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    return hash == _pinHash;
  }

  void lock() {
    if (_enabled && hasPin) locked.value = true;
  }

  void unlock() {
    locked.value = false;
  }
}
