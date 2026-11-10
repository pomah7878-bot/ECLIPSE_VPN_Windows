import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Приём deep-link'ов eclipsevpn:// на Windows.
///
/// Сервер после OAuth редиректит браузер на eclipsevpn://oauth-callback?code=...
/// Windows по зарегистрированному протоколу запускает ВТОРОЙ экземпляр
/// приложения с URL в аргументах; тот пересылает URL первому экземпляру
/// через локальный HTTP-порт и завершается.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const int port = 41731;
  static const String scheme = 'eclipsevpn://';

  HttpServer? _server;
  final _codeController = StreamController<String>.broadcast();
  String? _pendingCode;
  DateTime? _pendingCodeAt;

  /// Поток обменных кодов из deep-link'ов.
  Stream<String> get codes => _codeController.stream;

  /// Код, пришедший до того, как OAuth-поток начал его ждать.
  /// Коды живут 90 секунд — запоздавшие от старых вкладок отбрасываются.
  String? takePendingCode() {
    final code = _pendingCode;
    final at = _pendingCodeAt;
    _pendingCode = null;
    _pendingCodeAt = null;
    if (code == null || at == null) return null;
    if (DateTime.now().difference(at) > const Duration(seconds: 90)) {
      return null;
    }
    return code;
  }

  /// Сохраняет код из deep-link'а, полученного при холодном старте.
  void injectLaunchCode(String url) {
    final code = parseCode(url);
    if (code != null) {
      _pendingCode = code;
      _pendingCodeAt = DateTime.now();
    }
  }

  /// Извлекает code из eclipsevpn://oauth-callback?code=...
  static String? parseCode(String url) {
    if (!url.startsWith(scheme)) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final code = uri.queryParameters['code'];
    return (code == null || code.isEmpty) ? null : code;
  }

  /// Регистрирует обработчик протокола eclipsevpn:// в HKCU (без админ-прав).
  static Future<void> registerProtocolHandler() async {
    if (!Platform.isWindows) return;
    final exe = Platform.resolvedExecutable;
    const key = r'HKCU\Software\Classes\eclipsevpn';
    final commands = <List<String>>[
      ['add', key, '/ve', '/d', 'URL:ECLIPSE VPN', '/f'],
      ['add', key, '/v', 'URL Protocol', '/t', 'REG_SZ', '/d', '', '/f'],
      [
        'add',
        '$key\\shell\\open\\command',
        '/ve',
        '/d',
        '"$exe" "%1"',
        '/f',
      ],
    ];
    for (final c in commands) {
      try {
        await Process.run('reg', c);
      } catch (e) {
        debugPrint('Protocol registration failed: $e');
      }
    }
  }

  /// Локальный приёмник для второго экземпляра. Ошибка привязки порта
  /// означает, что первый экземпляр уже слушает — молча пропускаем.
  Future<void> startReceiver() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (e) {
      debugPrint('DeepLink receiver: порт занят ($e)');
      return;
    }
    _server!.listen((request) async {
      final url = request.uri.queryParameters['url'];
      if (request.uri.path == '/deeplink' && url != null) {
        final code = parseCode(url);
        if (code != null && !_codeController.isClosed) {
          _pendingCode = code;
          _pendingCodeAt = DateTime.now();
          _codeController.add(code);
        }
      }
      request.response
        ..statusCode = 200
        ..write('ok');
      await request.response.close();
    });
  }

  /// Пересылка deep-link'а из второго экземпляра первому.
  static Future<bool> forwardToRunningInstance(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:$port/deeplink?url=${Uri.encodeComponent(url)}',
        ),
      );
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Обработка аргумента командной строки при старте: если это deep-link —
  /// пересылаем_running-экземпляру и сообщаем, что пора завершиться.
  static Future<String?> handleLaunchArgs(List<String> args) async {
    for (final arg in args) {
      if (arg.startsWith(scheme)) return arg;
    }
    return null;
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    await _codeController.close();
  }
}
