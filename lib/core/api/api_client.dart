import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ApiClient {
  static const String baseUrl = 'https://ваш-домен.com'; // TODO: Заменить на реальный домен
  
  late final Dio _dio;
  final _cookieJar = CookieJar();
  
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
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
  
  // Сохранение/восстановление сессии
  Future<void> saveSession() async {
    // TODO: Сохранить cookies в SharedPreferences
  }
  
  Future<void> restoreSession() async {
    // TODO: Восстановить cookies из SharedPreferences
  }
  
  Future<void> clearSession() async {
    await _cookieJar.deleteAll();
  }
}
