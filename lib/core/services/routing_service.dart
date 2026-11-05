import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Сервис маршрутизации (аналог EclipseRoutingSync в Android)
class RoutingService {
  static const String routingEclipse = 'custom_routing_eclipse';
  static const String routingGlobal = 'custom_routing_global';
  static const String routingWhite = 'custom_routing_white';
  static const String routingBlack = 'custom_routing_black';
  static const String routingWhiteRussia = 'custom_routing_white_russia';

  String _currentRouting = routingEclipse;
  Map<String, dynamic>? _routingConfig;

  String get currentRouting => _currentRouting;

  /// Установить тип маршрутизации
  Future<void> setRoutingType(String type) async {
    _currentRouting = type;
    await _loadRoutingConfig();
  }

  /// Загрузить конфигурацию маршрутизации
  Future<void> _loadRoutingConfig() async {
    try {
      // Пробуем загрузить с сервера (как в Android EclipseRoutingSync)
      final config = await _fetchRoutingFromServer();
      if (config != null) {
        _routingConfig = config;
        await _saveLocalRouting(config);
        return;
      }
    } catch (e) {
      debugPrint('Error fetching routing: $e');
    }

    // Fallback на локальный файл
    _routingConfig = await _loadLocalRouting();
  }

  /// Получить маршрутизацию с сервера
  Future<Map<String, dynamic>?> _fetchRoutingFromServer() async {
    // TODO: Реальный API-запрос
    // GET /api/public/routing-config?type=custom_routing_eclipse
    return null;
  }

  /// Сохранить локально
  Future<void> _saveLocalRouting(Map<String, dynamic> config) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/routing_$_currentRouting.json');
    await file.writeAsString(jsonEncode(config));
  }

  /// Загрузить локальный файл
  Future<Map<String, dynamic>?> _loadLocalRouting() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/routing_$_currentRouting.json');
      if (await file.exists()) {
        return jsonDecode(await file.readAsString());
      }
    } catch (e) {
      debugPrint('Error loading local routing: $e');
    }
    return _getDefaultRouting();
  }

  /// Маршрутизация по умолчанию (Eclipse)
  Map<String, dynamic> _getDefaultRouting() {
    return {
      "domainStrategy": "IPIfNonMatch",
      "rules": [
        {
          "type": "field",
          "domain": [
            "geosite:category-ads-all"
          ],
          "outboundTag": "block"
        },
        {
          "type": "field",
          "domain": [
            "geosite:category-gov-ru",
            "geosite:yandex",
            "geosite:vk",
            "geosite:mailru"
          ],
          "outboundTag": "direct"
        },
        {
          "type": "field",
          "ip": [
            "geoip:private",
            "geoip:ru"
          ],
          "outboundTag": "direct"
        }
      ]
    };
  }

  /// Применить маршрутизацию к конфигу sing-box
  Map<String, dynamic> applyRouting(Map<String, dynamic> config) {
    if (_routingConfig == null) return config;

    // Конвертируем Xray-формат в sing-box формат
    final route = config['route'] as Map<String, dynamic>? ?? {};
    
    if (_routingConfig!.containsKey('rules')) {
      route['rules'] = _convertRules(_routingConfig!['rules']);
    }
    
    if (_routingConfig!.containsKey('domainStrategy')) {
      route['auto_detect_interface'] = _routingConfig!['domainStrategy'] == 'IPIfNonMatch';
    }

    config['route'] = route;
    return config;
  }

  /// Конвертировать правила Xray → sing-box
  List<Map<String, dynamic>> _convertRules(List<dynamic> rules) {
    return rules.map((rule) {
      final r = rule as Map<String, dynamic>;
      final converted = <String, dynamic>{};

      if (r.containsKey('domain')) {
        converted['domain_suffix'] = r['domain'];
      }
      if (r.containsKey('ip')) {
        converted['ip_cidr'] = r['ip'];
      }
      if (r.containsKey('outboundTag')) {
        converted['outbound'] = r['outboundTag'];
      }

      return converted;
    }).toList();
  }

  /// Получить список доступных маршрутизаций
  List<RoutingOption> getAvailableRoutings() {
    return [
      RoutingOption(
        id: routingEclipse,
        name: 'Eclipse (Умный)',
        description: 'Российские сайты напрямую, остальное через VPN',
      ),
      RoutingOption(
        id: routingGlobal,
        name: 'Глобальный',
        description: 'Весь трафик через VPN',
      ),
      RoutingOption(
        id: routingWhite,
        name: 'Белый список',
        description: 'Только выбранные сайты через VPN',
      ),
      RoutingOption(
        id: routingBlack,
        name: 'Чёрный список',
        description: 'Всё напрямую, кроме выбранных',
      ),
      RoutingOption(
        id: routingWhiteRussia,
        name: 'Россия (белый)',
        description: 'Российские сайты через VPN, остальное напрямую',
      ),
    ];
  }
}

class RoutingOption {
  final String id;
  final String name;
  final String description;

  RoutingOption({
    required this.id,
    required this.name,
    required this.description,
  });
}
