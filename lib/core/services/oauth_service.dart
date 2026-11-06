import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';

enum OAuthProvider {
  google,
  yandex,
  vk,
}

/// Сервис OAuth-авторизации.
///
/// Реализует PKCE (Proof Key for Code Exchange) как в Android:
/// 1. Генерирует code_verifier (32 случайных байта, base64url)
/// 2. Вычисляет code_challenge = SHA256(verifier), base64url
/// 3. Открывает браузер с challenge
/// 4. Получает code через локальный callback-сервер
/// 5. Обменивает code + verifier на cookie-сессию
class OAuthService {
  final _authApi = AuthApi();

  /// Запускает OAuth-поток через системный браузер
  Future<SessionLoginResponse> signInWithProvider(OAuthProvider provider) async {
    final providerName = _providerName(provider);

    // PKCE: генерируем verifier и challenge
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // Запускаем локальный сервер для приёма callback
    final callbackServer = await _startCallbackServer();
    final callbackUrl = 'http://127.0.0.1:${callbackServer.port}/oauth-callback';

    // Формируем URL авторизации
    final fullUrl =
        '${ApiClient.baseUrl}/api/public/account/oauth-exchange'
        '?provider=$providerName'
        '&redirect_uri=${Uri.encodeComponent(callbackUrl)}'
        '&code_challenge=$codeChallenge'
        '&code_challenge_method=S256';

    try {
      // Открываем браузер
      final uri = Uri.parse(fullUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Не удалось открыть браузер');
      }

      // Ждём callback от браузера
      final authCode = await callbackServer.waitForCode(
        timeout: const Duration(minutes: 2),
      );

      // Обмениваем код на сессию
      return await _authApi.exchangeOAuthCode(
        code: authCode,
        codeVerifier: codeVerifier,
      );
    } finally {
      await callbackServer.close();
    }
  }

  String _providerName(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return 'google';
      case OAuthProvider.yandex:
        return 'yandex';
      case OAuthProvider.vk:
        return 'vk';
    }
  }

  /// Генерирует PKCE code_verifier — 32 случайных байта в base64url
  String _generateCodeVerifier() {
    final bytes = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Вычисляет PKCE code_challenge = SHA256(verifier) в base64url
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<_CallbackServer> _startCallbackServer() async {
    return _CallbackServer.start();
  }
}

/// Локальный HTTP-сервер для приёма OAuth callback
class _CallbackServer {
  final HttpServer _server;
  final _codeCompleter = Completer<String>();

  _CallbackServer._(this._server);

  static Future<_CallbackServer> start() async {
    final server = await HttpServer.bind('127.0.0.1', 0); // Случайный порт
    final instance = _CallbackServer._(server);
    instance._listen();
    return instance;
  }

  int get port => _server.port;

  void _listen() async {
    await for (final request in _server) {
      final uri = request.uri;

      if (uri.path == '/oauth-callback') {
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (code != null && !_codeCompleter.isCompleted) {
          _codeCompleter.complete(code);
        } else if (error != null && !_codeCompleter.isCompleted) {
          _codeCompleter.completeError(Exception('OAuth error: $error'));
        }

        // Отправляем ответ браузеру
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('''
            <!DOCTYPE html>
            <html>
            <head><title>ECLIPSE VPN</title></head>
            <body style="font-family: system-ui; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #0a0a0f; color: white;">
              <div style="text-align: center;">
                <h1 style="color: #ffb800;">✓ Авторизация успешна</h1>
                <p>Можете закрыть это окно и вернуться в приложение.</p>
              </div>
            </body>
            </html>
          ''');
        await request.response.close();
      } else {
        request.response
          ..statusCode = 404
          ..write('Not found');
        await request.response.close();
      }
    }
  }

  Future<String> waitForCode({Duration? timeout}) async {
    if (timeout != null) {
      return _codeCompleter.future.timeout(
        timeout,
        onTimeout: () => throw Exception('Время ожидания авторизации истекло'),
      );
    }
    return _codeCompleter.future;
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}