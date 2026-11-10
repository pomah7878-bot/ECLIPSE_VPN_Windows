import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Единая точка входа в API ECLIPSE.
///
/// Совместимость с Android-приложением:
/// - Cookie-сессия сохраняется между запусками (PersistCookieJar)
/// - Заголовок X-Eclipse-App: 1
/// - Базовый URL: https://eclipse.unlimited.bot.nu/api
class ApiClient {
  static const String baseUrl = 'https://eclipse.unlimited.bot.nu';
  static const String apiBaseUrl = '$baseUrl/api';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  PersistCookieJar? _cookieJar;
  bool _initialized = false;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Eclipse-App': '1',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ));
    }
  }

  /// Должен быть вызван один раз из main() до любых запросов.
  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationSupportDirectory();
    final cookieDir = Directory(p.join(dir.path, 'cookies'));
    if (!cookieDir.existsSync()) {
      cookieDir.createSync(recursive: true);
    }
    _cookieJar = PersistCookieJar(storage: FileStorage(cookieDir.path));
    _dio.interceptors.add(CookieManager(_cookieJar!));
    _initialized = true;
  }

  Dio get dio => _dio;

  Future<void> clearSession() async {
    await _cookieJar?.deleteAll();
  }
}
