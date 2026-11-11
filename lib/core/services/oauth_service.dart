import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import 'deeplink_service.dart';

enum OAuthProvider { google, yandex }

/// OAuth-авторизация через системный браузер — как в Android-приложении.
///
/// 1. PKCE: code_verifier (32 байта, base64url), challenge = SHA256(verifier)
/// 2. Браузер открывает GET {site}/auth/{provider}/start?client=app&code_challenge=...
/// 3. Сервер после авторизации редиректит на eclipsevpn://oauth-callback?code=...
///    (Windows передаёт URL второму экземпляру, тот пересылает первому
///    через локальный порт — см. DeepLinkService)
/// 4. POST /api/public/account/oauth-exchange {code, code_verifier} → cookie-сессия
class OAuthService {
  final _authApi = AuthApi();

  /// Номер текущего потока входа: запоздавший код чужого потока
  /// (например, от закрытой вкладки Google) не будет использован молча.
  static int _flowId = 0;

  Future<SessionLoginResponse> signInWithProvider(OAuthProvider provider) async {
    final flow = ++_flowId;
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final startUrl = '${ApiClient.baseUrl}/auth/${_providerName(provider)}/start'
        '?client=app'
        '&code_challenge=$codeChallenge';

    // Код мог прийти ещё до подписки (запуск приложения по deep-link)
    final pending = DeepLinkService.instance.takePendingCode();
    final codeFuture = pending != null
        ? Future.value(pending)
        : DeepLinkService.instance.codes.first;

    final uri = Uri.parse(startUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Не удалось открыть браузер');
    }

    final authCode = await codeFuture.timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw Exception('Время ожидания авторизации истекло'),
    );

    if (flow != _flowId) {
      throw Exception('Попытка входа прервана новым запросом. Повторите вход.');
    }

    try {
      return await _authApi.exchangeOAuthCode(
        code: authCode,
        codeVerifier: codeVerifier,
      );
    } catch (e) {
      // Код мог прийти от другой вкладки/провайдера — объясняем человечно
      throw Exception(
        'Не удалось завершить вход: код авторизации не подошёл, '
        'устарел или уже использован.\nЗакройте лишние вкладки браузера '
        'и попробуйте ещё раз.',
      );
    }
  }

  String _providerName(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return 'google';
      case OAuthProvider.yandex:
        return 'yandex';
    }
  }

  String _generateCodeVerifier() {
    final bytes = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
