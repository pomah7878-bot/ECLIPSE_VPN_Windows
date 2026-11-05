import '../../../core/api/keys_api.dart';

/// Генератор конфигурации sing-box из данных ключа
class ConfigGenerator {
  
  /// Создаёт конфиг sing-box для VLESS/Reality
  static Map<String, dynamic> generateVlessConfig({
    required String server,
    required int port,
    required String uuid,
    required String publicKey,
    required String shortId,
    required String sni,
    String network = 'tcp',
  }) {
    return {
      "log": {
        "level": "info",
        "timestamp": true
      },
      "inbounds": [
        {
          "type": "tun",
          "tag": "tun-in",
          "interface_name": "EclipseVPN",
          "inet4_address": "172.19.0.1/30",
          "auto_route": true,
          "strict_route": true,
          "sniff": true
        }
      ],
      "outbounds": [
        {
          "type": "vless",
          "tag": "proxy",
          "server": server,
          "server_port": port,
          "uuid": uuid,
          "flow": "xtls-rprx-vision",
          "network": network,
          "tls": {
            "enabled": true,
            "server_name": sni,
            "utls": {
              "enabled": true,
              "fingerprint": "chrome"
            },
            "reality": {
              "enabled": true,
              "public_key": publicKey,
              "short_id": shortId
            }
          }
        },
        {
          "type": "direct",
          "tag": "direct"
        },
        {
          "type": "dns",
          "tag": "dns-out"
        }
      ],
      "route": {
        "rules": [
          {
            "protocol": "dns",
            "outbound": "dns-out"
          }
        ],
        "auto_detect_interface": true
      },
      "dns": {
        "servers": [
          {
            "tag": "remote",
            "address": "https://8.8.8.8/dns-query",
            "detour": "proxy"
          },
          {
            "tag": "local",
            "address": "223.5.5.5",
            "detour": "direct"
          }
        ]
      }
    };
  }

  /// Создаёт конфиг для Hysteria2
  static Map<String, dynamic> generateHysteria2Config({
    required String server,
    required int port,
    required String password,
    String? sni,
    String? fingerprint,
  }) {
    return {
      "log": {
        "level": "info",
        "timestamp": true
      },
      "inbounds": [
        {
          "type": "tun",
          "tag": "tun-in",
          "interface_name": "EclipseVPN",
          "inet4_address": "172.19.0.1/30",
          "auto_route": true,
          "strict_route": true,
          "sniff": true
        }
      ],
      "outbounds": [
        {
          "type": "hysteria2",
          "tag": "proxy",
          "server": server,
          "server_port": port,
          "password": password,
          "tls": {
            "enabled": true,
            if (sni != null) "server_name": sni,
            if (fingerprint != null) "utls": {
              "enabled": true,
              "fingerprint": fingerprint
            }
          }
        },
        {
          "type": "direct",
          "tag": "direct"
        }
      ],
      "route": {
        "auto_detect_interface": true
      }
    };
  }

  /// Парсит VLESS-ссылку в конфиг
  static Map<String, dynamic>? parseVlessUrl(String url) {
    try {
      if (!url.startsWith('vless://')) return null;
      
      final uri = Uri.parse(url);
      final uuid = uri.userInfo;
      final server = uri.host;
      final port = uri.port;
      
      final params = uri.queryParameters;
      final publicKey = params['pbk'] ?? '';
      final shortId = params['sid'] ?? '';
      final sni = params['sni'] ?? '';
      final flow = params['flow'] ?? 'xtls-rprx-vision';
      
      return generateVlessConfig(
        server: server,
        port: port,
        uuid: uuid,
        publicKey: publicKey,
        shortId: shortId,
        sni: sni,
      );
    } catch (e) {
      return null;
    }
  }

  /// Генерирует конфиг из KeyInbound
  static Map<String, dynamic>? fromKeyInbound(KeyInbound inbound) {
    if (inbound.link != null) {
      if (inbound.link!.startsWith('vless://')) {
        return parseVlessUrl(inbound.link!);
      }
      // TODO: Другие протоколы (hysteria2://, vmess:// и т.д.)
    }
    
    if (inbound.config != null) {
      // Если пришёл готовый JSON конфиг
      try {
        return inbound.config as Map<String, dynamic>;
      } catch (_) {}
    }
    
    return null;
  }
}
