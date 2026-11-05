import 'api_client.dart';

class TariffsApi {
  final _client = ApiClient();
  
  /// Получить список тарифов
  /// GET /api/tariffs
  Future<List<Tariff>> getTariffs() async {
    final response = await _client.dio.get('/api/tariffs');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['tariffs'] ?? response.data ?? [];
      return data.map((e) => Tariff.fromJson(e)).toList();
    } else {
      throw ApiException(message: 'Ошибка загрузки тарифов');
    }
  }
  
  /// Получить публичные тарифы (для витрины)
  /// GET /api/public/tariffs
  Future<List<Tariff>> getPublicTariffs() async {
    final response = await _client.dio.get('/api/public/tariffs');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['tariffs'] ?? response.data ?? [];
      return data.map((e) => Tariff.fromJson(e)).toList();
    } else {
      throw ApiException(message: 'Ошибка загрузки тарифов');
    }
  }
}

class Tariff {
  final int id;
  final String name;
  final int price;
  final int durationDays;
  final int? trafficLimitMb;
  final int? deviceLimit;
  final String? description;
  final bool isActive;
  
  Tariff({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    this.trafficLimitMb,
    this.deviceLimit,
    this.description,
    required this.isActive,
  });
  
  factory Tariff.fromJson(Map<String, dynamic> json) {
    return Tariff(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Тариф',
      price: json['price'] ?? 0,
      durationDays: json['duration_days'] ?? json['days'] ?? 30,
      trafficLimitMb: json['traffic_limit_mb'],
      deviceLimit: json['device_limit'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }
  
  String get priceFormatted => '$price ₽';
  String get durationFormatted => '$durationDays дн.';
}

class ApiException implements Exception {
  final String message;
  
  ApiException({required this.message});
  
  @override
  String toString() => message;
}
