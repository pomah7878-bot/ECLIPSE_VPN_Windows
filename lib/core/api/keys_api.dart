import 'package:dio/dio.dart';
import 'api_client.dart';

class KeysApi {
  final _client = ApiClient();
  
  /// Получить список ключей пользователя
  /// GET /api/keys
  Future<List<VpnKey>> getKeys() async {
    final response = await _client.dio.get('/api/keys');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['keys'] ?? response.data ?? [];
      return data.map((e) => VpnKey.fromJson(e)).toList();
    } else {
      throw ApiException(message: 'Ошибка загрузки ключей');
    }
  }
  
  /// Получить подключения для ключа
  /// GET /api/key/{key_id}/inbounds
  Future<List<KeyInbound>> getKeyInbounds(int keyId) async {
    final response = await _client.dio.get('/api/key/$keyId/inbounds');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['inbounds'] ?? response.data ?? [];
      return data.map((e) => KeyInbound.fromJson(e)).toList();
    } else {
      throw ApiException(message: 'Ошибка загрузки подключений');
    }
  }
  
  /// Получить публичные подключения (без сессии, по ID ключа)
  /// GET /api/public/key/{key_id}/inbounds
  Future<List<KeyInbound>> getPublicKeyInbounds(int keyId) async {
    final response = await _client.dio.get('/api/public/key/$keyId/inbounds');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data['inbounds'] ?? response.data ?? [];
      return data.map((e) => KeyInbound.fromJson(e)).toList();
    } else {
      throw ApiException(message: 'Ошибка загрузки подключений');
    }
  }
}

class VpnKey {
  final int id;
  final String name;
  final String? serverName;
  final String? protocol;
  final DateTime? expiryDate;
  final bool isActive;
  final int? trafficUsedMb;
  final int? trafficLimitMb;
  
  VpnKey({
    required this.id,
    required this.name,
    this.serverName,
    this.protocol,
    this.expiryDate,
    required this.isActive,
    this.trafficUsedMb,
    this.trafficLimitMb,
  });
  
  factory VpnKey.fromJson(Map<String, dynamic> json) {
    return VpnKey(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Ключ #${json['id']}',
      serverName: json['server_name'] ?? json['server'],
      protocol: json['protocol'],
      expiryDate: json['expiry_date'] != null 
          ? DateTime.tryParse(json['expiry_date']) 
          : null,
      isActive: json['is_active'] ?? true,
      trafficUsedMb: json['traffic_used_mb'],
      trafficLimitMb: json['traffic_limit_mb'],
    );
  }
  
  int? get daysLeft {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
}

class KeyInbound {
  final int id;
  final String protocol;
  final String? link;
  final String? config;
  final String? qrCode;
  
  KeyInbound({
    required this.id,
    required this.protocol,
    this.link,
    this.config,
    this.qrCode,
  });
  
  factory KeyInbound.fromJson(Map<String, dynamic> json) {
    return KeyInbound(
      id: json['id'] ?? 0,
      protocol: json['protocol'] ?? 'unknown',
      link: json['link'] ?? json['url'],
      config: json['config'],
      qrCode: json['qr_code'],
    );
  }
}

class ApiException implements Exception {
  final String message;
  
  ApiException({required this.message});
  
  @override
  String toString() => message;
}
