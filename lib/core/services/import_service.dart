import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Импортированная подписка (гостевой режим): ссылка на подписку или
/// одиночный конфиг, сохранённые без входа в аккаунт.
class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  static const _key = 'imported_subscription_url';
  static const _bodyKey = 'imported_subscription_body';

  SharedPreferences? _prefs;
  String? _url;
  String? _body;

  final ValueNotifier<bool> hasImport = ValueNotifier<bool>(false);

  String? get url => _url;
  String? get body => _body;
  bool get isImported =>
      (_url != null && _url!.isNotEmpty) || (_body != null && _body!.isNotEmpty);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final value = _prefs?.getString(_key);
    final rawBody = _prefs?.getString(_bodyKey);
    _url = (value == null || value.isEmpty) ? null : value;
    _body = (rawBody == null || rawBody.isEmpty) ? null : rawBody;
    hasImport.value = isImported;
  }

  Future<void> setUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _url = trimmed;
    _body = null;
    await _prefs?.setString(_key, trimmed);
    await _prefs?.remove(_bodyKey);
    hasImport.value = true;
  }

  /// Тело подписки, полученное с телефона по QR (base64 или список ссылок).
  Future<void> setBody(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _body = trimmed;
    _url = null;
    await _prefs?.setString(_bodyKey, trimmed);
    await _prefs?.remove(_key);
    hasImport.value = true;
  }

  Future<void> clear() async {
    _url = null;
    _body = null;
    await _prefs?.remove(_key);
    await _prefs?.remove(_bodyKey);
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
