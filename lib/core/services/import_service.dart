import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Импортированная подписка (гостевой режим): ссылка на подписку или
/// одиночный конфиг, сохранённые без входа в аккаунт.
class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  static const _key = 'imported_subscription_url';

  SharedPreferences? _prefs;
  String? _url;

  final ValueNotifier<bool> hasImport = ValueNotifier<bool>(false);

  String? get url => _url;
  bool get isImported => _url != null && _url!.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final value = _prefs?.getString(_key);
    _url = (value == null || value.isEmpty) ? null : value;
    hasImport.value = isImported;
  }

  Future<void> setUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _url = trimmed;
    await _prefs?.setString(_key, trimmed);
    hasImport.value = true;
  }

  Future<void> clear() async {
    _url = null;
    await _prefs?.remove(_key);
    hasImport.value = false;
  }

  /// Поддерживаемые ссылки: подписка http(s) или прямой конфиг.
  static bool looksSupported(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    const prefixes = [
      'vless://',
      'vmess://',
      'trojan://',
      'hysteria2://',
      'hy2://',
      'http://',
      'https://',
    ];
    return prefixes.any(v.startsWith);
  }
}
