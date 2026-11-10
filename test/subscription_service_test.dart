import 'dart:convert';

import 'package:eclipse_vpn_windows/core/services/subscription_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const link1 = 'vless://uuid-1@1.2.3.4:443?security=reality&sni=a.com&pbk=key#DE-1';
  const link2 = 'vless://uuid-2@5.6.7.8:443?type=tcp#NL-2';

  group('SubscriptionService.parseBody', () {
    test('plain-текст: ссылки построчно', () {
      final servers = SubscriptionService.parseBody('$link1\n$link2\n');
      expect(servers.length, 2);
      expect(servers[0].name, 'DE-1');
      expect(servers[0].link, link1);
      expect(servers[1].name, 'NL-2');
    });

    test('base64-тело распаковывается', () {
      final body = base64.encode(utf8.encode('$link1\n$link2'));
      final servers = SubscriptionService.parseBody(body);
      expect(servers.length, 2);
      expect(servers[0].name, 'DE-1');
    });

    test('base64 с переносами строк (MIME) распаковывается', () {
      final body = base64
          .encode(utf8.encode('$link1\n$link2'))
          .replaceAllMapped(RegExp(r'.{64}'), (m) => '${m.group(0)}\n');
      final servers = SubscriptionService.parseBody(body);
      expect(servers.length, 2);
    });

    test('мусорные строки пропускаются, битые ссылки не ломают список', () {
      const body = 'hello\n$link1\nnot-a-link://x\n\n   \n$link2';
      final servers = SubscriptionService.parseBody(body);
      expect(servers.length, 2);
    });

    test('пустое тело -> пустой список', () {
      expect(SubscriptionService.parseBody(''), isEmpty);
      expect(SubscriptionService.parseBody('   \n  '), isEmpty);
    });

    test('имя берётся из fragment, а при его отсутствии — из host', () {
      final servers =
          SubscriptionService.parseBody('vless://uuid@9.9.9.9:443?type=tcp');
      expect(servers.length, 1);
      expect(servers[0].name, '9.9.9.9');
    });
  });
}
