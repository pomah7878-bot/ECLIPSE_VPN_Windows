import 'package:dio/dio.dart';
import 'api_client.dart';

/// API для авторизации и управления сессией.
///
/// Полностью совместим с Android ShopApiClient:
/// - sessionLogin — вход по коду доступа из бота
/// - getSession — проверка текущей сессии
/// - exchangeOAuthCode — обмен OAuth кода на сессию
/// - logout — выход
/// - linkBotCode — привязка OAuth аккаунта к боту
class AuthApi {
  final _client = ApiClient();

  /// Вход по коду доступа из бота.
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

  /// Проверка текущей сессии.
  /// GET /public/account/session
  Future<AccountSessionResponse?> getSession() async {
    try {
      final response = await _client.dio.get('/public/account/session');
      if (response.statusCode == 200) {
        return AccountSessionResponse.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Выход из аккаунта.
  /// POST /public/account/logout
  Future<void> logout() async {
    await _client.dio.post('/public/account/logout');
    await _client.clearSession();
  }

  /// OAuth-обмен кода на сессию.
  /// POST /public/account/oauth-exchange
  Future<SessionLoginResponse> exchangeOAuthCode({
    required String code,
    String? codeVerifier,
  }) async {
    final data = <String, dynamic>{'code': code};
    if (codeVerifier != null && codeVerifier.isNotEmpty) {
      data['code_verifier'] = codeVerifier;
    }

    final response = await _client.dio.post(
      '/public/account/oauth-exchange',
      data: data,
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

  /// Привязка текущего OAuth-аккаунта к существующему клиенту бота.
  /// POST /public/account/link-code
  Future<LinkCodeResponse> linkBotCode(String code) async {
    final response = await _client.dio.post(
      '/public/account/link-code',
      data: {'code': code},
    );

    if (response.statusCode == 200) {
      return LinkCodeResponse.fromJson(response.data);
    } else {
      throw ApiException(
        message: response.data['message'] ?? 'Ошибка привязки',
      );
    }
  }
}

// ==================== DTO ====================

class SessionLoginResponse {
  final bool ok;
  final String accountType;

  SessionLoginResponse({required this.ok, required this.accountType});
}

/// Данные сессии аккаунта — полная совместимость с Android.
class AccountSessionResponse {
  final bool ok;
  final bool loggedIn;
  final String? accountType;
  final bool canLinkOauth;
  final List<AccountKeyDto> keys;
  final String? balanceHuman;

  AccountSessionResponse({
    required this.ok,
    required this.loggedIn,
    this.accountType,
    required this.canLinkOauth,
    required this.keys,
    this.balanceHuman,
  });

  factory AccountSessionResponse.fromJson(Map<String, dynamic> json) {
    return AccountSessionResponse(
      ok: json['ok'] ?? false,
      loggedIn: json['logged_in'] ?? false,
      accountType: json['account_type'],
      canLinkOauth: json['can_link_oauth'] ?? false,
      keys: _parseList(json['keys']).map((e) => AccountKeyDto.fromJson(e)).toList(),
      balanceHuman: json['balance_human'],
    );
  }

  static List<dynamic> _parseList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return [value];
    return [];
  }
}

/// Ключ VPN пользователя.
class AccountKeyDto {
  final int keyId;
  final String displayName;
  final DateTime? expiresAt;
  final int trafficUsed;
  final int trafficLimit;
  final bool isActive;
  final String? serverName;
  final String? subUrl;

  AccountKeyDto({
    required this.keyId,
    required this.displayName,
    this.expiresAt,
    required this.trafficUsed,
    required this.trafficLimit,
    required this.isActive,
    this.serverName,
    this.subUrl,
  });

  factory AccountKeyDto.fromJson(Map<String, dynamic> json) {
    return AccountKeyDto(
      keyId: json['key_id'] ?? 0,
      displayName: json['display_name'] ?? 'Ключ #${json['key_id']}',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
      trafficUsed: json['traffic_used'] ?? 0,
      trafficLimit: json['traffic_limit'] ?? 0,
      isActive: json['is_active'] ?? true,
      serverName: json['server_name'],
      subUrl: json['sub_url'],
    );
  }

  int? get daysLeft {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  double get trafficUsedGb => trafficUsed / (1024 * 1024 * 1024);

  double? get trafficLimitGb =>
      trafficLimit > 0 ? trafficLimit / (1024 * 1024 * 1024) : null;
}

class LinkCodeResponse {
  final bool ok;
  final String? message;

  LinkCodeResponse({required this.ok, this.message});

  factory LinkCodeResponse.fromJson(Map<String, dynamic> json) {
    return LinkCodeResponse(
      ok: json['ok'] ?? false,
      message: json['message'],
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