import 'package:dio/dio.dart';
import 'api_client.dart';

/// API для покупки подписок (аналог PurchaseActivity в Android)
class ShopApi {
  final _client = ApiClient();

  /// Создание платежа
  /// POST /api/pay/create
  Future<PaymentCreateResponse> createPayment({
    required int tariffId,
    int? keyId,
    String? promoCode,
    String paymentMethod = 'card',
  }) async {
    final response = await _client.dio.post(
      '/api/pay/create',
      data: {
        'tariff_id': tariffId,
        if (keyId != null) 'key_id': keyId,
        if (promoCode != null) 'promo_code': promoCode,
        'payment_method': paymentMethod,
      },
    );

    if (response.statusCode == 200 && response.data['ok'] == true) {
      return PaymentCreateResponse.fromJson(response.data);
    } else {
      throw ApiException(
        message: response.data['message'] ?? 'Ошибка создания платежа',
      );
    }
  }

  /// Проверка статуса платежа
  /// POST /api/pay/check
  Future<PaymentStatus> checkPayment(String paymentId) async {
    final response = await _client.dio.post(
      '/api/pay/check',
      data: {'payment_id': paymentId},
    );

    if (response.statusCode == 200) {
      return PaymentStatus.fromJson(response.data);
    } else {
      throw ApiException(message: 'Ошибка проверки платежа');
    }
  }

  /// Пополнение баланса
  /// POST /api/balance/topup
  Future<PaymentCreateResponse> topUpBalance(int amount) async {
    final response = await _client.dio.post(
      '/api/balance/topup',
      data: {'amount': amount},
    );

    if (response.statusCode == 200 && response.data['ok'] == true) {
      return PaymentCreateResponse.fromJson(response.data);
    } else {
      throw ApiException(
        message: response.data['message'] ?? 'Ошибка пополнения баланса',
      );
    }
  }

  /// Получение баланса
  /// GET /api/balance
  Future<double> getBalance() async {
    final response = await _client.dio.get('/api/balance');
    if (response.statusCode == 200) {
      return (response.data['balance'] ?? 0).toDouble();
    }
    return 0.0;
  }

  /// История платежей
  /// GET /api/history
  Future<List<PaymentHistoryItem>> getPaymentHistory() async {
    final response = await _client.dio.get('/api/history');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['history'] ?? [];
      return data.map((e) => PaymentHistoryItem.fromJson(e)).toList();
    }
    return [];
  }
}

class PaymentCreateResponse {
  final String paymentId;
  final String? paymentUrl;
  final String? confirmationUrl;
  final double amount;
  final String status;

  PaymentCreateResponse({
    required this.paymentId,
    this.paymentUrl,
    this.confirmationUrl,
    required this.amount,
    required this.status,
  });

  factory PaymentCreateResponse.fromJson(Map<String, dynamic> json) {
    return PaymentCreateResponse(
      paymentId: json['payment_id'] ?? '',
      paymentUrl: json['payment_url'],
      confirmationUrl: json['confirmation_url'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
    );
  }
}

class PaymentStatus {
  final String status;
  final String? message;
  final bool isCompleted;

  PaymentStatus({
    required this.status,
    this.message,
    required this.isCompleted,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ?? 'unknown';
    return PaymentStatus(
      status: status,
      message: json['message'],
      isCompleted: status == 'succeeded' || status == 'completed',
    );
  }
}

class PaymentHistoryItem {
  final String id;
  final double amount;
  final String description;
  final DateTime date;
  final String status;

  PaymentHistoryItem({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.status,
  });

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryItem(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? '',
    );
  }
}

class ApiException implements Exception {
  final String message;

  ApiException({required this.message});

  @override
  String toString() => message;
}
