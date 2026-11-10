import 'dart:convert';

import 'package:dio/dio.dart';

import 'settings_service.dart';

/// Сервер из подписки: имя (из #fragment) и ссылка-конфиг.
class SubscriptionServer {
  final String name;
  final String link;

  SubscriptionServer({required this.name, required this.link});
}

/// Загрузка подписки ключа — как в Android-приложении.
///
/// GET {sub_url} с заголовками X-Eclipse-App: 1 и X-HWID: <id устройства>.
/// Тело — base64 (MIME) списка ссылок или ссылки простым текстом.
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.plain,
    headers: {
      'X-Eclipse-App': '1',
      'User-Agent': 'ECLIPSE-Windows/0.2.0',
    },
  ));

  static const _supportedSchemes = [
    'vless://',
    'vmess://',
    'trojan://',
    'hysteria2://',
    'hy2://',
  ];

  Future<List<SubscriptionServer>> fetch(String subUrl) async {
    final response = await _dio.get(
      subUrl,
      options: Options(headers: {'X-HWID': SettingsService().deviceId}),
    );
    return parseBody('${response.data}');
  }

  /// Тело подписки: base64 (MIME) списка ссылок или ссылки простым текстом.
  static List<SubscriptionServer> parseBody(String body) {
    var text = body.trim();
    if (text.isEmpty) return [];

    if (!text.contains('://')) {
      try {
        // MIME-base64 может содержать переносы строк — убираем их перед декодированием
        final compact = text.replaceAll(RegExp(r'\s+'), '');
        text = utf8.decode(base64.decode(base64.normalize(compact)));
      } catch (_) {
        return [];
      }
    }

    final servers = <SubscriptionServer>[];
    for (var line in text.split(RegExp(r'\r?\n'))) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (!_supportedSchemes.any(line.startsWith)) continue;
      servers.add(SubscriptionServer(name: _nameOf(line), link: line));
    }
    return servers;
  }

  static String _nameOf(String link) {
    try {
      final fragment = Uri.parse(link).fragment;
      if (fragment.isNotEmpty) return Uri.decodeComponent(fragment);
      return Uri.parse(link).host;
    } catch (_) {
      return '';
    }
  }
}
