import 'package:eclipse_vpn_windows/core/services/config_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLink', () {
    test('vless + reality', () {
      const link =
          'vless://2f7b6c1e-8d3a-4b5c-9e2f-1a2b3c4d5e6f@1.2.3.4:443'
          '?security=reality&sni=example.com&fp=chrome'
          '&pbk=XvAE4VnGkHpadcYRaqTqgMvzRv_-U8Ejr6sKJxjBsG0&sid=aabbccdd'
          '&flow=xtls-rprx-vision&type=tcp#DE-1';

      final out = ConfigGenerator.parseLink(link);
      expect(out, isNotNull);
      expect(out!['type'], 'vless');
      expect(out['tag'], 'proxy');
      expect(out['server'], '1.2.3.4');
      expect(out['server_port'], 443);
      expect(out['uuid'], '2f7b6c1e-8d3a-4b5c-9e2f-1a2b3c4d5e6f');
      expect(out['flow'], 'xtls-rprx-vision');

      final tls = out['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'example.com');
      final reality = tls['reality'] as Map<String, dynamic>;
      expect(reality['enabled'], true);
      expect(reality['public_key'],
          'XvAE4VnGkHpadcYRaqTqgMvzRv_-U8Ejr6sKJxjBsG0');
      expect(reality['short_id'], 'aabbccdd');
      expect((tls['utls'] as Map)['fingerprint'], 'chrome');
      expect(out['transport'], isNull);
    });

    test('vless + ws transport', () {
      const link =
          'vless://uuid-1234@example.com:8443?security=tls&sni=cdn.example.com'
          '&type=ws&host=cdn.example.com&path=%2Fwebsocket#WS';

      final out = ConfigGenerator.parseLink(link);
      expect(out, isNotNull);
      final tls = out!['tls'] as Map<String, dynamic>;
      expect(tls['server_name'], 'cdn.example.com');
      expect(tls.containsKey('reality'), false);
      final tr = out['transport'] as Map<String, dynamic>;
      expect(tr['type'], 'ws');
      expect(tr['path'], '/websocket');
      expect((tr['headers'] as Map)['Host'], 'cdn.example.com');
    });

    test('vmess base64', () {
      // {"v":"2","ps":"test","add":"1.2.3.4","port":"443","id":"uuid-1",
      //  "aid":"0","scy":"auto","net":"tcp","tls":"tls","sni":"example.com"}
      const link = 'vmess://eyJ2IjoiMiIsInBzIjoidGVzdCIsImFkZCI6IjEuMi4zLjQi'
          'LCJwb3J0IjoiNDQzIiwiaWQiOiJ1dWlkLTEiLCJhaWQiOiIwIiwic2N5IjoiYXV0byIs'
          'Im5ldCI6InRjcCIsInRscyI6InRscyIsInNuaSI6ImV4YW1wbGUuY29tIn0=';

      final out = ConfigGenerator.parseLink(link);
      expect(out, isNotNull);
      expect(out!['type'], 'vmess');
      expect(out['server'], '1.2.3.4');
      expect(out['server_port'], 443);
      expect(out['uuid'], 'uuid-1');
      expect((out['tls'] as Map)['server_name'], 'example.com');
    });

    test('trojan', () {
      const link = 'trojan://pass1234@5.6.7.8:443?sni=trojan.example.com';
      final out = ConfigGenerator.parseLink(link);
      expect(out, isNotNull);
      expect(out!['type'], 'trojan');
      expect(out['password'], 'pass1234');
      expect(out['server_port'], 443);
      expect((out['tls'] as Map)['server_name'], 'trojan.example.com');
    });

    test('hysteria2', () {
      const link = 'hysteria2://secretpw@9.9.9.9:8443?sni=h2.example.com&insecure=1';
      final out = ConfigGenerator.parseLink(link);
      expect(out, isNotNull);
      expect(out!['type'], 'hysteria2');
      expect(out['password'], 'secretpw');
      final tls = out['tls'] as Map<String, dynamic>;
      expect(tls['server_name'], 'h2.example.com');
      expect(tls['insecure'], true);
    });

    test('hy2:// alias', () {
      const link = 'hy2://pw@1.1.1.1:443?sni=x.com';
      expect(ConfigGenerator.parseLink(link), isNotNull);
    });

    test('неподдерживаемая ссылка -> null', () {
      expect(ConfigGenerator.parseLink('ss://abc'), isNull);
      expect(ConfigGenerator.parseLink(''), isNull);
      expect(ConfigGenerator.parseLink('https://example.com'), isNull);
    });

    test('битый vmess -> null', () {
      expect(ConfigGenerator.parseLink('vmess://!!!not-base64!!!'), isNull);
    });
  });

  group('generate', () {
    const link =
        'vless://uuid@1.2.3.4:443?security=reality&sni=example.com'
        '&pbk=XvAE4VnGkHpadcYRaqTqgMvzRv_-U8Ejr6sKJxjBsG0&sid=ab'
        '&fp=chrome&flow=xtls-rprx-vision';

    Map<String, dynamic> routeOf(Map<String, dynamic> cfg) =>
        cfg['route'] as Map<String, dynamic>;

    test('global: без rule_set, final=proxy', () {
      final cfg = ConfigGenerator.generate(
          link: link, mode: RoutingMode.global);
      expect(cfg, isNotNull);
      final route = routeOf(cfg!);
      expect(route.containsKey('rule_set'), false);
      expect(route['final'], 'proxy');
      expect(route['default_domain_resolver'], 'dns_local');
    });

    test('smart: rule_set RU -> direct, final=proxy', () {
      final cfg = ConfigGenerator.generate(
          link: link, mode: RoutingMode.smart)!;
      final route = routeOf(cfg);
      expect(route['final'], 'proxy');
      final ruleSets = route['rule_set'] as List;
      expect(ruleSets.length, 2);
      final ruRule = (route['rules'] as List).firstWhere(
          (r) => (r as Map).containsKey('rule_set') && r['rule_set'] is List);
      expect((ruRule as Map)['outbound'], 'direct');
    });

    test('smart: http_clients вместо устаревшего download_detour', () {
      final cfg = ConfigGenerator.generate(
          link: link, mode: RoutingMode.smart)!;
      final clients = cfg['http_clients'] as List;
      expect((clients[0] as Map)['detour'], 'proxy');
      expect(routeOf(cfg)['default_http_client'], 'rs_client');
      for (final rs in routeOf(cfg)['rule_set'] as List) {
        expect((rs as Map).containsKey('download_detour'), false);
      }
    });

    test('global: нет http_clients (rule-set не используются)', () {
      final cfg = ConfigGenerator.generate(
          link: link, mode: RoutingMode.global)!;
      expect(cfg.containsKey('http_clients'), false);
      expect(routeOf(cfg).containsKey('default_http_client'), false);
    });

    test('ruThroughVpn: rule_set RU -> proxy, final=direct', () {
      final cfg = ConfigGenerator.generate(
          link: link, mode: RoutingMode.ruThroughVpn)!;
      final route = routeOf(cfg);
      expect(route['final'], 'direct');
      final ruRule = (route['rules'] as List).firstWhere(
          (r) => (r as Map).containsKey('rule_set') && r['rule_set'] is List);
      expect((ruRule as Map)['outbound'], 'proxy');
    });

    test('общая структура конфига', () {
      final cfg = ConfigGenerator.generate(
          link: link, mode: RoutingMode.smart)!;

      // DNS
      final dns = cfg['dns'] as Map<String, dynamic>;
      final servers = dns['servers'] as List;
      expect(servers.length, 3);
      expect((servers[0] as Map)['server'], '8.8.8.8');
      expect(dns['strategy'], 'ipv4_only');

      // TUN inbound
      final inbounds = cfg['inbounds'] as List;
      final tun = inbounds[0] as Map;
      expect(tun['type'], 'tun');
      expect(tun['interface_name'], 'EclipseVPN');
      expect(tun['address'], isA<List>());
      expect(tun['stack'], 'gvisor');

      // Outbounds: direct + proxy
      final outbounds = cfg['outbounds'] as List;
      expect(outbounds.length, 2);
      expect((outbounds[0] as Map)['type'], 'direct');
      expect((outbounds[1] as Map)['tag'], 'proxy');

      // Route-правила: sniff + hijack-dns + private
      final rules = (cfg['route'] as Map)['rules'] as List;
      expect((rules[0] as Map)['action'], 'sniff');
      expect((rules[1] as Map)['action'], 'hijack-dns');
      expect((rules[2] as Map)['ip_is_private'], true);
    });

    test('нерaзбираемая ссылка -> null', () {
      expect(
        ConfigGenerator.generate(link: 'garbage', mode: RoutingMode.global),
        isNull,
      );
    });
  });

  group('RoutingModeX', () {
    test('fromId с валидным и невалидным id', () {
      expect(RoutingModeX.fromId('global'), RoutingMode.global);
      expect(RoutingModeX.fromId('unknown'), RoutingMode.smart);
      expect(RoutingModeX.fromId(null), RoutingMode.smart);
    });

    test('у каждого режима есть заголовок и описание', () {
      for (final mode in RoutingMode.values) {
        expect(mode.title, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });
  });
}
