import 'api_client.dart';
import 'api_exception.dart';

/// API ключей: список inbound-конфигов для подключения.
class KeysApi {
  final _client = ApiClient();

  /// GET /key/{id}/inbounds
  Future<List<KeyInbound>> getKeyInbounds(int keyId) async {
    final response = await _client.dio.get('/key/$keyId/inbounds');
    if (response.statusCode == 200) {
      return _extractList(response.data, 'inbounds')
          .whereType<Map<String, dynamic>>()
          .map(KeyInbound.fromJson)
          .toList();
    }
    throw ApiException(message: 'Ошибка загрузки подключений');
  }

  /// GET /public/key/{id}/inbounds
  Future<List<KeyInbound>> getPublicKeyInbounds(int keyId) async {
    final response = await _client.dio.get('/public/key/$keyId/inbounds');
    if (response.statusCode == 200) {
      return _extractList(response.data, 'inbounds')
          .whereType<Map<String, dynamic>>()
          .map(KeyInbound.fromJson)
          .toList();
    }
    throw ApiException(message: 'Ошибка загрузки подключений');
  }

  /// POST /public/account/key/devices — устройства ключа (как в Android).
  Future<KeyDevicesResponse> getKeyDevices(int keyId) async {
    final response = await _client.dio.post(
      '/public/account/key/devices',
      data: {'key_id': keyId},
    );
    if (response.statusCode == 200) {
      return KeyDevicesResponse.fromJson(response.data);
    }
    throw ApiException(message: 'Ошибка загрузки устройств');
  }

  /// POST /public/account/key/device_disconnect — освободить слот устройства.
  /// Возвращает null при успехе или текст ошибки.
  Future<String?> disconnectDevice(int keyId, Object deviceId) async {
    final response = await _client.dio.post(
      '/public/account/key/device_disconnect',
      data: {'key_id': keyId, 'device_id': deviceId},
    );
    if (response.statusCode == 200 && response.data['status'] == 'ok') {
      return null;
    }
    final msg = response.data['message']?.toString() ?? '';
    return msg.isEmpty ? 'Не удалось отключить устройство' : msg;
  }

  /// Безопасно извлекает List из ответа сервера.
  static List<dynamic> _extractList(dynamic data, String field) {
    if (data is Map<String, dynamic>) {
      final value = data[field];
      if (value is List) return value;
      if (value is Map) return [value];
      return [];
    }
    if (data is List) return data;
    return [];
  }
}

/// Один inbound сервера (протокол + ссылка-конфиг).
class KeyInbound {
  final int id;
  final String protocol;
  final String? link;
  final String? config;
  final String? remark;

  KeyInbound({
    required this.id,
    required this.protocol,
    this.link,
    this.config,
    this.remark,
  });

  factory KeyInbound.fromJson(Map<String, dynamic> json) {
    return KeyInbound(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      protocol: json['protocol']?.toString() ?? 'unknown',
      link: (json['link'] ?? json['url'])?.toString(),
      config: json['config']?.toString(),
      remark: (json['remark'] ?? json['name'])?.toString(),
    );
  }
}

/// Ответ /public/account/key/devices.
class KeyDevicesResponse {
  final int currentCount;
  final int maxDevices;
  final List<DeviceDto> devices;

  KeyDevicesResponse({
    required this.currentCount,
    required this.maxDevices,
    required this.devices,
  });

  factory KeyDevicesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['devices'];
    final list = raw is List ? raw : const <dynamic>[];
    return KeyDevicesResponse(
      currentCount: _asInt(json['current_count']),
      maxDevices: _asInt(json['max_devices']),
      devices: list
          .whereType<Map<String, dynamic>>()
          .map(DeviceDto.fromJson)
          .toList(),
    );
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  String get counterText =>
      maxDevices > 0 ? '$currentCount из $maxDevices' : '$currentCount';
}

/// Одно устройство ключа.
class DeviceDto {
  final String model;
  final String os;
  final String osVersion;
  final String ip;
  final String lastSeen;
  final String firstSeen;
  final dynamic deviceId;

  DeviceDto({
    required this.model,
    required this.os,
    required this.osVersion,
    required this.ip,
    required this.lastSeen,
    required this.firstSeen,
    this.deviceId,
  });

  factory DeviceDto.fromJson(Map<String, dynamic> json) {
    return DeviceDto(
      model: json['model']?.toString() ?? '',
      os: json['os']?.toString() ?? '',
      osVersion: json['os_version']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      lastSeen: json['last_seen']?.toString() ?? '',
      firstSeen: json['first_seen']?.toString() ?? '',
      deviceId: json['device_id'],
    );
  }

  bool get canDisconnect => deviceId != null;

  String get title {
    for (final v in [model, os, ip]) {
      if (v.isNotEmpty) return v;
    }
    return 'Устройство';
  }

  String get info {
    final osFull = '$os $osVersion'.trim();
    final seen = formatSeen(lastSeen.isNotEmpty ? lastSeen : firstSeen);
    final parts = <String>[
      if (osFull.isNotEmpty && osFull != title) osFull,
      if (seen.isNotEmpty) 'был в сети $seen',
    ];
    return parts.join(' • ');
  }

  /// Метки времени панели приходят в unix-секундах (или мс); остальное — как есть.
  static String formatSeen(String raw) {
    if (raw.isEmpty) return '';
    final v = int.tryParse(raw.trim());
    if (v == null) return raw;
    var ms = v;
    if (ms < 100000000000) ms *= 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}, '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
