import 'dart:convert';

/// Режимы маршрутизации трафика.
enum RoutingMode {
  /// Весь трафик через VPN.
  global,

  /// Российские ресурсы напрямую, остальное через VPN.
  smart,

  /// Российские ресурсы через VPN, остальное напрямую.
  ruThroughVpn,
}

extension RoutingModeX on RoutingMode {
  String get id => name;

  String get title {
    switch (this) {
      case RoutingMode.global:
        return 'Как у всех';
      case RoutingMode.smart:
        return 'Умный';
      case RoutingMode.ruThroughVpn:
        return 'Белые списки';
    }
  }

  String get description {
    switch (this) {
      case RoutingMode.global:
        return 'Весь трафик через VPN';
      case RoutingMode.smart:
        return 'Российские сайты напрямую, остальной трафик через VPN';
      case RoutingMode.ruThroughVpn:
        return 'Для сетей с белыми списками: российские сервисы через VPN, остальное напрямую';
    }
  }

  static RoutingMode fromId(String? id) {
    return RoutingMode.values.firstWhere(
      (m) => m.name == id,
      orElse: () => RoutingMode.smart,
    );
  }
}

/// Генератор конфигурации sing-box 1.11+ (проверено на 1.14.x).
///
/// Особенности формата:
/// - DNS-серверы: {"type": "udp", "server": ..., "detour": ...}
/// - TUN: поле address (список CIDR)
/// - Route-правила: action sniff / hijack-dns / route+outbound
/// - Обязателен route.default_domain_resolver
/// - Rule-set'ы geoip-ru/geosite-ru подгружаются удалённо (.srs),
///   локальные geoip.db/geosite.db НЕ нужны
class ConfigGenerator {
  static const String tunInterfaceName = 'EclipseVPN';

  /// Строит полный конфиг sing-box из ссылки-подключения.
  ///
  /// Возвращает null, если ссылку не удалось разобрать.
  static Map<String, dynamic>? generate({
    required String link,
    required RoutingMode mode,
  }) {
    final proxy = parseLink(link);
    if (proxy == null) return null;

    final useRuleSets = mode != RoutingMode.global;

    final dnsRules = <Map<String, dynamic>>[];
    if (mode == RoutingMode.smart) {
      dnsRules.add({'rule_set': 'geosite-ru', 'server': 'dns_local'});
    }

    final routeRules = <Map<String, dynamic>>[
      {'action': 'sniff'},
      {'protocol': 'dns', 'action': 'hijack-dns'},
      {
        'ip_is_private': true,
        'action': 'route',
        'outbound': 'direct',
      },
    ];

    if (mode == RoutingMode.smart) {
      routeRules.add({
        'rule_set': ['geoip-ru', 'geosite-ru'],
        'action': 'route',
        'outbound': 'direct',
      });
    } else if (mode == RoutingMode.ruThroughVpn) {
      routeRules.add({
        'rule_set': ['geoip-ru', 'geosite-ru'],
        'action': 'route',
        'outbound': 'proxy',
      });
    }

    return {
      'log': {'level': 'info', 'timestamp': true},
      'dns': {
        'servers': [
          {
            'type': 'udp',
            'tag': 'dns_remote',
            'server': '8.8.8.8',
            'detour': 'proxy',
          },
          {
            'type': 'udp',
            'tag': 'dns_local',
            'server': '1.1.1.1',
          },
          {'type': 'hosts', 'tag': 'dns_hosts'},
        ],
        'rules': dnsRules,
        'final': 'dns_remote',
        'strategy': 'ipv4_only',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': tunInterfaceName,
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'auto_route': true,
          'strict_route': true,
          'stack': 'gvisor',
        },
      ],
      'outbounds': [
        {'type': 'direct', 'tag': 'direct'},
        proxy,
      ],
      'route': {
        'rules': routeRules,
        if (useRuleSets)
          'rule_set': [
            {
              'type': 'remote',
              'tag': 'geoip-ru',
              'url':
                  'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs',
              'download_detour': 'proxy',
            },
            {
              'type': 'remote',
              'tag': 'geosite-ru',
              'url':
                  'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs',
              'download_detour': 'proxy',
            },
          ],
        'auto_detect_interface': true,
        'default_domain_resolver': 'dns_local',
        'final': mode == RoutingMode.ruThroughVpn ? 'direct' : 'proxy',
      },
    };
  }

  // ==================== ПАРСЕРЫ ССЫЛОК ====================

  /// Разбирает vless:// / vmess:// / trojan:// / hysteria2:// (hy2://).
  /// Возвращает outbound-объект sing-box или null.
  static Map<String, dynamic>? parseLink(String link) {
    final trimmed = link.trim();
    if (trimmed.startsWith('vless://')) return _parseVless(trimmed);
    if (trimmed.startsWith('vmess://')) return _parseVmess(trimmed);
    if (trimmed.startsWith('trojan://')) return _parseTrojan(trimmed);
    if (trimmed.startsWith('hysteria2://') || trimmed.startsWith('hy2://')) {
      return _parseHysteria2(trimmed);
    }
    return null;
  }

  static Map<String, dynamic>? _parseVless(String url) {
    try {
      final uri = Uri.parse(url);
      final uuid = Uri.decodeComponent(uri.userInfo);
      if (uuid.isEmpty || uri.host.isEmpty) return null;

      final params = uri.queryParameters;
      final out = <String, dynamic>{
        'type': 'vless',
        'tag': 'proxy',
        'server': uri.host,
        'server_port': uri.port,
        'uuid': uuid,
      };

      final flow = params['flow'];
      if (flow != null && flow.isNotEmpty) out['flow'] = flow;

      final tls = _parseTls(params, uri.host);
      if (tls != null) out['tls'] = tls;

      final transport = _parseTransport(params);
      if (transport != null) out['transport'] = transport;

      return out;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseVmess(String url) {
    try {
      final b64 = url.substring('vmess://'.length).split('#').first;
      final str = utf8.decode(base64.decode(base64.normalize(b64)));
      final v = jsonDecode(str) as Map<String, dynamic>;

      final out = <String, dynamic>{
        'type': 'vmess',
        'tag': 'proxy',
        'server': v['add'],
        'server_port': int.parse('${v['port']}'),
        'uuid': v['id'],
        'security': v['scy'] ?? 'auto',
        'alter_id': int.tryParse('${v['aid']}') ?? 0,
      };

      if ('${v['tls']}' == 'tls') {
        final sni = v['sni'] ?? v['host'];
        out['tls'] = {
          'enabled': true,
          if (sni != null && '$sni'.isNotEmpty) 'server_name': '$sni',
        };
      }

      final net = '${v['net'] ?? 'tcp'}';
      if (net != 'tcp') {
        final tr = <String, dynamic>{'type': net};
        if (v['host'] != null && '${v['host']}'.isNotEmpty) tr['host'] = '${v['host']}';
        if (v['path'] != null && '${v['path']}'.isNotEmpty) tr['path'] = '${v['path']}';
        out['transport'] = tr;
      }

      return out;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseTrojan(String url) {
    try {
      final uri = Uri.parse(url);
      final password = Uri.decodeComponent(uri.userInfo);
      if (password.isEmpty || uri.host.isEmpty) return null;

      final params = uri.queryParameters;
      final out = <String, dynamic>{
        'type': 'trojan',
        'tag': 'proxy',
        'server': uri.host,
        'server_port': uri.port,
        'password': password,
      };

      // Trojan всегда работает поверх TLS: если security не указан —
      // считаем его tls, чтобы sni-параметр был учтён.
      final effectiveParams = Map<String, String>.from(params);
      effectiveParams.putIfAbsent('security', () => 'tls');
      final tls = _parseTls(effectiveParams, uri.host);
      out['tls'] = tls ??
          {
            'enabled': true,
            'server_name': params['sni'] ?? params['serverName'] ?? uri.host,
          };

      final transport = _parseTransport(params);
      if (transport != null) out['transport'] = transport;

      return out;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseHysteria2(String url) {
    try {
      final normalized =
          url.startsWith('hy2://') ? url.replaceFirst('hy2://', 'hysteria2://') : url;
      final uri = Uri.parse(normalized);
      final password = Uri.decodeComponent(uri.userInfo);
      if (password.isEmpty || uri.host.isEmpty) return null;

      final params = uri.queryParameters;
      final out = <String, dynamic>{
        'type': 'hysteria2',
        'tag': 'proxy',
        'server': uri.host,
        'server_port': uri.port,
        'password': password,
        'tls': {
          'enabled': true,
          'server_name': params['sni'] ?? uri.host,
          if (params['insecure'] == '1') 'insecure': true,
        },
      };
      return out;
    } catch (_) {
      return null;
    }
  }

  /// TLS/Reality из query-параметров (security=reality|tls).
  static Map<String, dynamic>? _parseTls(
    Map<String, String> params,
    String host,
  ) {
    final security = params['security'] ?? '';
    if (security != 'tls' && security != 'reality') return null;

    final tls = <String, dynamic>{
      'enabled': true,
      'server_name': (params['sni'] ?? params['serverName']) ?? host,
    };

    if (security == 'reality') {
      tls['reality'] = {
        'enabled': true,
        'public_key': params['pbk'] ?? '',
        if (params['sid'] != null) 'short_id': params['sid'],
      };
      final fp = params['fp'];
      if (fp != null && fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
    }

    final alpn = params['alpn'];
    if (alpn != null && alpn.isNotEmpty) {
      tls['alpn'] = alpn.split(',');
    }

    return tls;
  }

  /// Транспорт (ws/grpc/http) из query-параметров.
  static Map<String, dynamic>? _parseTransport(Map<String, String> params) {
    final type = params['type'] ?? 'tcp';
    if (type == 'tcp') return null;

    final tr = <String, dynamic>{'type': type};
    switch (type) {
      case 'ws':
      case 'http':
        final host = params['host'];
        if (host != null && host.isNotEmpty) tr['headers'] = {'Host': host};
        final path = params['path'];
        if (path != null && path.isNotEmpty) tr['path'] = path;
        break;
      case 'grpc':
        final serviceName = params['serviceName'];
        if (serviceName != null && serviceName.isNotEmpty) {
          tr['service_name'] = serviceName;
        }
        break;
    }
    return tr;
  }
}
