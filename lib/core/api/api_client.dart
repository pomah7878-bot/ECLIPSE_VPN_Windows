import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ApiClient {
  static const String baseUrl = 'https://eclipse.unlimited.bot.nu';
  static const String apiBaseUrl = '$baseUrl/api';

  late final Dio _dio;
  final _cookieJar = CookieJar();

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(CookieManager(_cookieJar));

    // Логирование в debug-режиме
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));
  }

  Dio get dio => _dio;

  Future<void> clearSession() async {
    await _cookieJar.deleteAll();
  }
}