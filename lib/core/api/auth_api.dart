import 'api_client.dart';
import 'api_exception.dart';

/// Авторизация и управление сессией.
///
/// Совместимо с Android ShopApiClient:
/// - sessionLogin — вход по коду доступа из бота
/// - getSession — проверка текущей сессии
/// - exchangeOAuthCode — обмен OAuth-кода на сессию
/// - linkBotCode — привязка OAuth-аккаунта к боту
/// - logout — выход
class AuthApi {
  final _client = ApiClient();

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
    }
    throw ApiException(
      message: response.data['message'] ?? 'Ошибка входа',
      code: response.data['error']?.toString(),
    );
  }

  /// GET /public/account/session
  Future<AccountSessionResponse?> getSession() async {
    try {
      final response = await _client.dio.get('/public/account/session');
      if (response.statusCode == 200) {
        return AccountSessionResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      if (e is ApiException) rethrow;
      final status = _statusCodeOf(e);
      if (status == 401) return null;
      rethrow;
    }
  }

  /// POST /public/account/logout
  Future<void> logout() async {
    try {
      await _client.dio.post('/public/account/logout');
    } finally {
      await _client.clearSession();
    }
  }

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
    }
    throw ApiException(
      message: response.data['message'] ?? 'Ошибка OAuth',
      code: response.data['error']?.toString(),
    );
  }

  /// POST /public/account/link-code
  Future<LinkCodeResponse> linkBotCode(String code) async {
    final response = await _client.dio.post(
      '/public/account/link-code',
      data: {'code': code},
    );

    if (response.statusCode == 200) {
      return LinkCodeResponse.fromJson(response.data);
    }
    throw ApiException(message: 'Ошибка привязки');
  }

  /// POST /public/auth/phone/request — инициирует звонок для входа по номеру.
  Future<PhoneRequestResponse> requestPhone(String phone) async {
    try {
      final response = await _client.dio.post(
        '/public/auth/phone/request',
        data: {'phone': phone},
      );
      if (response.statusCode == 200 && response.data['status'] == 'ok') {
        return PhoneRequestResponse.fromJson(response.data);
      }
      throw ApiException(
        message: response.data['message']?.toString() ?? 'Не удалось запросить звонок',
        code: response.data['error']?.toString(),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      final data = _errorData(e);
      throw ApiException(
        message: data?['message']?.toString() ?? 'Не удалось запросить звонок',
        code: data?['error']?.toString(),
      );
    }
  }

  /// POST /public/auth/phone/check — проверка подтверждения номера.
  Future<PhoneCheckResponse> checkPhone({
    required String phone,
    required String callId,
    String? enteredCode,
  }) async {
    final data = <String, dynamic>{'phone': phone, 'call_id': callId};
    if (enteredCode != null && enteredCode.isNotEmpty) {
      data['entered_code'] = enteredCode;
    }
    try {
      final response = await _client.dio.post('/public/auth/phone/check', data: data);
      if (response.statusCode == 200) {
        return PhoneCheckResponse.fromJson(response.data);
      }
      return PhoneCheckResponse(verified: false, message: 'Не удалось проверить номер');
    } catch (e) {
      final data = _errorData(e);
      return PhoneCheckResponse(
        verified: false,
        message: data?['message']?.toString() ?? 'Не удалось проверить номер',
      );
    }
  }

  static Map<String, dynamic>? _errorData(Object e) {
    try {
      final dynamic d = e;
      final data = d.response?.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      // ignore
    }
    return null;
  }

  static int? _statusCodeOf(Object e) {
    try {
      final dynamic d = e;
      return d.response?.statusCode as int?;
    } catch (_) {
      return null;
    }
  }
}

// ==================== DTO ====================

class SessionLoginResponse {
  final bool ok;
  final String accountType;

  SessionLoginResponse({required this.ok, required this.accountType});
}

/// Данные сессии аккаунта.
class AccountSessionResponse {
  final bool ok;
  final bool loggedIn;
  final String? accountType;
  final bool canLinkOauth;
  final List<AccountKeyDto> keys;
  final String? balanceHuman;
  final int balanceCents;
  final String? phone;
  final String? email;
  final String? avatarBase64;

  AccountSessionResponse({
    required this.ok,
    required this.loggedIn,
    this.accountType,
    required this.canLinkOauth,
    required this.keys,
    this.balanceHuman,
    this.balanceCents = 0,
    this.phone,
    this.email,
    this.avatarBase64,
  });

  factory AccountSessionResponse.fromJson(Map<String, dynamic> json) {
    return AccountSessionResponse(
      ok: json['ok'] ?? false,
      loggedIn: json['logged_in'] ?? false,
      accountType: json['account_type']?.toString(),
      canLinkOauth: json['can_link_oauth'] ?? false,
      keys: _asList(json['keys'])
          .whereType<Map<String, dynamic>>()
          .map(AccountKeyDto.fromJson)
          .toList(),
      balanceHuman: json['balance_human']?.toString(),
      balanceCents: _asInt(json['balance_cents']),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      avatarBase64: json['avatar_base64']?.toString(),
    );
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  static List<dynamic> _asList(dynamic value) {
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
      keyId: _asInt(json['key_id']),
      displayName: json['display_name']?.toString() ?? 'Ключ #${json['key_id']}',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      trafficUsed: _asInt(json['traffic_used']),
      trafficLimit: _asInt(json['traffic_limit']),
      isActive: json['is_active'] ?? true,
      serverName: json['server_name']?.toString(),
      subUrl: json['sub_url']?.toString(),
    );
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

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
      message: json['message']?.toString(),
    );
  }
}

class PhoneRequestResponse {
  final String method;
  final String? callId;
  final String? pincode;
  final List<String> allowedPhones;

  PhoneRequestResponse({
    required this.method,
    this.callId,
    this.pincode,
    this.allowedPhones = const [],
  });

  factory PhoneRequestResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['allowed_phones_for_call'];
    final list = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    return PhoneRequestResponse(
      method: json['method']?.toString() ?? 'flash_call',
      callId: json['call_id']?.toString(),
      pincode: json['pincode']?.toString(),
      allowedPhones: list,
    );
  }

  bool get needsCode => method == 'voice_code' || method == 'flashcall_real';
}

class PhoneCheckResponse {
  final bool verified;
  final String? message;
  final String? accountType;

  PhoneCheckResponse({required this.verified, this.message, this.accountType});

  factory PhoneCheckResponse.fromJson(Map<String, dynamic> json) {
    return PhoneCheckResponse(
      verified: json['verified'] == true,
      message: json['message']?.toString(),
      accountType: json['account_type']?.toString(),
    );
  }
}
