class Tariff {
  final int id;
  final String name;
  final int durationDays;
  final double price;
  final String currency;
  final bool isActive;
  final int? trafficLimit;
  final int? deviceLimit;

  Tariff({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.price,
    required this.currency,
    required this.isActive,
    this.trafficLimit,
    this.deviceLimit,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) {
    return Tariff(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Тариф',
      durationDays: json['duration_days'] ?? 30,
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'RUB',
      isActive: json['is_active'] ?? true,
      trafficLimit: json['traffic_limit'],
      deviceLimit: json['device_limit'],
    );
  }

  String get priceFormatted => '${price.toStringAsFixed(0)} $currency';
  String get durationFormatted => '$durationDays дн.';
}

class AccountStatus {
  final int totalKeys;
  final int activeKeys;
  final String trafficTotalUsed;
  final ExpiryInfo? nearestExpiry;
  final bool hasKeys;
  final String? botUsername;
  final bool trialAvailable;

  AccountStatus({
    required this.totalKeys,
    required this.activeKeys,
    required this.trafficTotalUsed,
    this.nearestExpiry,
    required this.hasKeys,
    this.botUsername,
    required this.trialAvailable,
  });

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    return AccountStatus(
      totalKeys: json['total_keys'] ?? 0,
      activeKeys: json['active_keys'] ?? 0,
      trafficTotalUsed: json['traffic_total_used'] ?? '0 B',
      nearestExpiry: json['nearest_expiry'] != null
          ? ExpiryInfo.fromJson(json['nearest_expiry'])
          : null,
      hasKeys: json['has_keys'] ?? false,
      botUsername: json['bot_username'],
      trialAvailable: json['trial_available'] ?? false,
    );
  }
}

// Импортируем ExpiryInfo из key_model
import 'key_model.dart';
