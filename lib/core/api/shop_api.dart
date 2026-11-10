import 'api_client.dart';
import 'api_exception.dart';

/// Магазин: тарифы, пробный период, платежи ЮKassa, продление ключей.
///
/// Совместимо с Android ShopApiClient.
class ShopApi {
  final _client = ApiClient();

  /// GET /public/tariffs
  Future<TariffsResponse> getTariffs() async {
    final response = await _client.dio.get('/public/tariffs');
    if (response.statusCode == 200) {
      return TariffsResponse.fromJson(response.data);
    }
    throw ApiException(message: 'Ошибка загрузки тарифов');
  }

  /// POST /public/trial/create
  Future<TrialCreateResponse> createTrial() async {
    final response = await _client.dio.post('/public/trial/create', data: {});
    if (response.statusCode == 200) {
      return TrialCreateResponse.fromJson(response.data);
    }
    throw ApiException(message: 'Ошибка создания пробного периода');
  }

  /// POST /public/pay/create
  Future<PayCreateResponse> createPayment(int tariffId) async {
    final response = await _client.dio.post(
      '/public/pay/create',
      data: {'tariff_id': tariffId},
    );
    if (response.statusCode == 200) {
      final parsed = PayCreateResponse.fromJson(response.data);
      if (parsed.orderId == null) {
        throw ApiException(message: parsed.error ?? 'Не удалось создать платёж');
      }
      return parsed;
    }
    throw ApiException(message: 'Ошибка создания платежа');
  }

  /// POST /public/pay/check
  Future<PayCheckResponse> checkPayment(String orderId) async {
    final response = await _client.dio.post(
      '/public/pay/check',
      data: {'order_id': orderId},
    );
    if (response.statusCode == 200) {
      return PayCheckResponse.fromJson(response.data);
    }
    throw ApiException(message: 'Ошибка проверки платежа');
  }

  /// POST /public/account/key/renew/create
  Future<KeyRenewCreateResponse> createKeyRenewal(int keyId) async {
    final response = await _client.dio.post(
      '/public/account/key/renew/create',
      data: {'key_id': keyId},
    );
    if (response.statusCode == 200) {
      final parsed = KeyRenewCreateResponse.fromJson(response.data);
      if (parsed.error != null) {
        throw ApiException(message: parsed.message ?? parsed.error!);
      }
      return parsed;
    }
    throw ApiException(message: 'Ошибка создания продления');
  }

  /// POST /public/account/key/renew/check
  Future<KeyRenewCheckResponse> checkKeyRenewal(String orderId) async {
    final response = await _client.dio.post(
      '/public/account/key/renew/check',
      data: {'order_id': orderId},
    );
    if (response.statusCode == 200) {
      return KeyRenewCheckResponse.fromJson(response.data);
    }
    throw ApiException(message: 'Ошибка проверки продления');
  }
}

// ==================== DTO ====================

class TariffsResponse {
  final List<TariffDto> tariffs;
  final bool trialAvailable;

  TariffsResponse({required this.tariffs, required this.trialAvailable});

  factory TariffsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tariffs'];
    final list = raw is List
        ? raw
        : (raw is Map ? [raw] : const <dynamic>[]);
    return TariffsResponse(
      tariffs: list
          .whereType<Map<String, dynamic>>()
          .map(TariffDto.fromJson)
          .toList(),
      trialAvailable: json['trial_available'] ?? false,
    );
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
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? 'Тариф',
      durationDays: _asInt(json['duration_days'], 30),
      priceRub: _asDouble(json['price_rub']),
      trafficLimitGb: json['traffic_limit_gb'] == null
          ? null
          : _asDouble(json['traffic_limit_gb']),
      isCurrent: json['is_current'] ?? false,
    );
  }

  static int _asInt(dynamic v, [int def = 0]) =>
      v is int ? v : int.tryParse('$v') ?? def;

  static double _asDouble(dynamic v) =>
      v is double ? v : double.tryParse('$v') ?? 0;

  String get priceFormatted => '${priceRub.toStringAsFixed(0)} ₽';
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
      status: json['status']?.toString(),
      claimCode: json['claim_code']?.toString(),
      subUrl: json['sub_url']?.toString(),
      error: json['error']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class PayCreateResponse {
  final String? orderId;
  final String? qrUrl;
  final double? amountRub;
  final String? error;

  PayCreateResponse({this.orderId, this.qrUrl, this.amountRub, this.error});

  factory PayCreateResponse.fromJson(Map<String, dynamic> json) {
    return PayCreateResponse(
      orderId: json['order_id']?.toString(),
      qrUrl: json['qr_url']?.toString(),
      amountRub: json['amount_rub'] == null
          ? null
          : double.tryParse('${json['amount_rub']}'),
      error: json['error']?.toString(),
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
      status: json['status']?.toString() ?? 'pending',
      claimCode: json['claim_code']?.toString(),
      subUrl: json['sub_url']?.toString(),
      message: json['message']?.toString(),
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
      orderId: json['order_id']?.toString(),
      qrUrl: json['qr_url']?.toString(),
      amountRub: json['amount_rub'] == null
          ? null
          : double.tryParse('${json['amount_rub']}'),
      error: json['error']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class KeyRenewCheckResponse {
  final String? status;
  final String? message;

  KeyRenewCheckResponse({this.status, this.message});

  factory KeyRenewCheckResponse.fromJson(Map<String, dynamic> json) {
    return KeyRenewCheckResponse(
      status: json['status']?.toString(),
      message: json['message']?.toString(),
    );
  }
}
