import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthApi {
  final _client = ApiClient();
  
  /// Вход по коду доступа из бота
  /// POST /public/account/session-login
  Future<SessionLoginResponse> loginWithCode(String code) async {
    final response = await _client.dio.post(
      '/public/account/session-login',
      data: {'code': code},
    );
    
    if (response.statusCode == 200 && response.data['ok'] == true) {
      return SessionLoginResponse(
        ok: true,
        accountType: response.data['account_type'] ?? 'telegram',
      );
    } else {
      throw ApiException(
        message: response.data['message'] ?? 'Ошибка входа',
        code: response.data['error'],
      );
    }
  }
  
  /// Проверка текущей сессии
  /// GET /public/account/session
  Future<SessionInfo?> getSession() async {
    try {
      final response = await _client.dio.get('/public/account/session');
      if (response.statusCode == 200 && response.data['ok'] == true) {
        return SessionInfo.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }
  
  /// Выход
  /// POST /public/account/logout
  Future<void> logout() async {
    await _client.dio.post('/public/account/logout');
    await _client.clearSession();
  }
  
  /// OAuth-обмен кода на сессию
  /// POST /public/account/oauth-exchange
  Future<SessionLoginResponse> exchangeOAuthCode({
    required String code,
    String? codeVerifier,
  }) async {
    final response = await _client.dio.post(
      '/public/account/oauth-exchange',
      data: {
        'code': code,
        if (codeVerifier != null) 'code_verifier': codeVerifier,
      },
    );
    
    if (response.statusCode == 200 && response.data['ok'] == true) {
      return SessionLoginResponse(
        ok: true,
        accountType: response.data['account_type'] ?? 'oauth',
      );
    } else {
      throw ApiException(
        message: response.data['message'] ?? 'Ошибка OAuth',
        code: response.data['error'],
      );
    }
  }
}

class SessionLoginResponse {
  final bool ok;
  final String accountType;
  
  SessionLoginResponse({required this.ok, required this.accountType});
}

class SessionInfo {
  final String accountType;
  final int? telegramId;
  final String? email;
  final String? phone;
  
  SessionInfo({
    required this.accountType,
    this.telegramId,
    this.email,
    this.phone,
  });
  
  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      accountType: json['account_type'] ?? 'unknown',
      telegramId: json['telegram_id'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}

class ApiException implements Exception {
  final String message;
  final String? code;
  
  ApiException({required this.message, this.code});
  
  @override
  String toString() => message;
}