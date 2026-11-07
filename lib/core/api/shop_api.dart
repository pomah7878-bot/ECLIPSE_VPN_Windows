import 'package:dio/dio.dart';
import 'api_client.dart';

/// API для магазина — тарифы, пробный период, платежи, продление ключей.
///
/// Полностью совместим с Android ShopApiClient.
class ShopApi {
  final _client = ApiClient();

  // ==================== ТАРИФЫ ====================

  /// Список тарифов.
  /// GET /public/tariffs
  Future<TariffsResponse> getTariffs() async {
    final response = await _client.dio.get('/public/tariffs');
    if (response.statusCode == 200) {
      return TariffsResponse.fromJson(response.data);
    } else {
      throw _ApiException(message: 'Ошибка загрузки тарифов');
    }
  }

  // ==================== ПРОБНЫЙ ПЕРИОД ====================

  /// Активирует бесплатный пробный период.
  /// POST /public/trial/create
  Future<TrialCreateResponse> createTrial() async {
    final response = await _client.dio.post(
      '/public/trial/create',
      data: {},
    );
    if (response.statusCode == 200) {
      return TrialCreateResponse.fromJson(response.data);
    } else {
      throw _ApiException(message: 'Ошибка создания пробного периода');
    }
  }

  // ==================== ПЛАТЕЖИ ====================

  /// Создаёт платёж ЮKassa за выбранный тариф.
  /// POST /public/pay/create
  Future<PayCreateResponse> createPayment(int tariffId) async {
    final response = await _client.dio.post(
      '/public/pay/create',
      data: {'tariff_id': tariffId},
    );
    if (response.statusCode == 200) {
      final parsed = PayCreateResponse.fromJson(response.data);
      if (parsed.orderId == null) {
        throw _ApiException(message: parsed.error ?? 'Не удалось создать платёж');
      }
      return parsed;
    } else {
      throw _ApiException(message: 'Ошибка создания платежа');
    }
  }

  /// Проверяет статус платежа.
  /// POST /public/pay/check
  Future<PayCheckResponse> checkPayment(String orderId) async {
    final response = await _client.dio.post(
      '/public/pay/check',
      data: {'order_id': orderId},
    );
    if (response.statusCode == 200) {
      return PayCheckResponse.fromJson(response.data);
    } else {
      throw _ApiException(message: 'Ошибка проверки платежа');
    }
  }

  // ==================== ПРОДЛЕНИЕ КЛЮЧА ====================

  /// Создаёт платёж для продления существующего ключа.
  /// POST /public/account/key/renew/create
  Future<KeyRenewCreateResponse> createKeyRenewal(int keyId) async {
    final response = await _client.dio.post(
      '/public/account/key/renew/create',
      data: {'key_id': keyId},
    );
    if (response.statusCode == 200) {
      final parsed = KeyRenewCreateResponse.fromJson(response.data);
      if (parsed.error != null) {
        throw _ApiException(message: parsed.message ?? parsed.error!);
      }
      return parsed;
    } else {
      throw _ApiException(message: 'Ошибка создания продления');
    }
  }

  /// Проверяет статус продления.
  /// POST /public/account/key/renew/check
  Future<KeyRenewCheckResponse> checkKeyRenewal(String orderId) async {
    final response = await _client.dio.post(
      '/public/account/key/renew/check',
      data: {'order_id': orderId},
    );
    if (response.statusCode == 200) {
      return KeyRenewCheckResponse.fromJson(response.data);
    } else {
      throw _ApiException(message: 'Ошибка проверки продления');
    }
  }
}

// ==================== DTO ====================

class TariffsResponse {
  final List<TariffDto> tariffs;
  final bool trialAvailable;

  TariffsResponse({required this.tariffs, required this.trialAvailable});

  factory TariffsResponse.fromJson(Map<String, dynamic> json) {
    return TariffsResponse(
      tariffs: _parseList(json['tariffs']).map((e) => TariffDto.fromJson(e)).toList(),
      trialAvailable: json['trial_available'] ?? false,
    );
  }

  static List<dynamic> _parseList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return [value];
    return [];
  }
}

class TariffDto {
  final int id;
  final String name;
  final int durationDays;
  final double priceRub;
  final double? trafficLimitGb;
  final bool isCurrent;

  TariffDto({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.priceRub,
    this.trafficLimitGb,
    required this.isCurrent,
  });

  factory TariffDto.fromJson(Map<String, dynamic> json) {
    return TariffDto(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Тариф',
      durationDays: json['duration_days'] ?? 30,
      priceRub: (json['price_rub'] ?? 0).toDouble(),
      trafficLimitGb: json['traffic_limit_gb']?.toDouble(),
      isCurrent: json['is_current'] ?? false,
    );
  }

  String get priceFormatted => '${priceRub.toStringAsFixed(0)} ₽';
  String get durationFormatted => '$durationDays дн.';
}

class TrialCreateResponse {
  final String? status;
  final String? claimCode;
  final String? subUrl;
  final String? error;
  final String? message;

  TrialCreateResponse({
    this.status,
    this.claimCode,
    this.subUrl,
    this.error,
    this.message,
  });

  factory TrialCreateResponse.fromJson(Map<String, dynamic> json) {
    return TrialCreateResponse(
      status: json['status'],
      claimCode: json['claim_code'],
      subUrl: json['sub_url'],
      error: json['error'],
      message: json['message'],
    );
  }
}

class PayCreateResponse {
  final String? orderId;
  final String? qrUrl;
  final double? amountRub;
  final String? error;

  PayCreateResponse({
    this.orderId,
    this.qrUrl,
    this.amountRub,
    this.error,
  });

  factory PayCreateResponse.fromJson(Map<String, dynamic> json) {
    return PayCreateResponse(
      orderId: json['order_id'],
      qrUrl: json['qr_url'],
      amountRub: json['amount_rub']?.toDouble(),
      error: json['error'],
    );
  }
}

class PayCheckResponse {
  final String status;
  final String? claimCode;
  final String? subUrl;
  final String? message;

  PayCheckResponse({
    required this.status,
    this.claimCode,
    this.subUrl,
    this.message,
  });

  factory PayCheckResponse.fromJson(Map<String, dynamic> json) {
    return PayCheckResponse(
      status: json['status'] ?? 'pending',
      claimCode: json['claim_code'],
      subUrl: json['sub_url'],
      message: json['message'],
    );
  }
}

class KeyRenewCreateResponse {
  final String? orderId;
  final String? qrUrl;
  final double? amountRub;
  final String? error;
  final String? message;

  KeyRenewCreateResponse({
    this.orderId,
    this.qrUrl,
    this.amountRub,
    this.error,
    this.message,
  });

  factory KeyRenewCreateResponse.fromJson(Map<String, dynamic> json) {
    return KeyRenewCreateResponse(
      orderId: json['order_id'],
      qrUrl: json['qr_url'],
      amountRub: json['amount_rub']?.toDouble(),
      error: json['error'],
      message: json['message'],
    );
  }
}

class KeyRenewCheckResponse {
  final String? status;
  final String? message;

  KeyRenewCheckResponse({this.status, this.message});

  factory KeyRenewCheckResponse.fromJson(Map<String, dynamic> json) {
    return KeyRenewCheckResponse(
      status: json['status'],
      message: json['message'],
    );
  }
}

class _ApiException implements Exception {
  final String message;

  _ApiException({required this.message});

  @override
  String toString() => message;
}